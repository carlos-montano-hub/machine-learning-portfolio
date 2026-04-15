# Pipeline de Analisis - E-Commerce Olist

Pipeline de datos de extremo a extremo que transforma datos crudos de e-commerce brasileno (Olist) en un esquema estrella analitico, utilizando PostgreSQL, Apache Flink CDC y Apache Doris.

## Arquitectura

```
Archivos CSV ──> PostgreSQL ──> Flink CDC ──> Doris (staging) ──> Doris (warehouse) ──> Superset
   (crudos)       (origen)     (streaming)     (base olist)     (esquema estrella)       (BI)
```

---

## Fases del Pipeline

### Fase 0 — Infraestructura

Levanta todos los servicios con Docker Compose: PostgreSQL 16 (con WAL logico habilitado para CDC), Apache Doris standalone, y un cluster de Flink con JobManager, TaskManager y SQL Client.

```bash
docker compose up -d
```

<details>
<summary>docker-compose.yaml completo</summary>

```yaml
services:
  postgres:
    image: postgres:16
    container_name: bda_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres_user
      POSTGRES_PASSWORD: postgres_pass
      POSTGRES_DB: olist
    ports:
      - "5435:5432"
    volumes:
      - postgres16_data:/var/lib/postgresql/data
    command:
      - postgres
      - -c
      - wal_level=logical          # Habilita replicacion logica para CDC
      - -c
      - max_replication_slots=32   # Slots para Flink CDC (uno por tabla)
      - -c
      - max_wal_senders=32

  doris:
    image: yagagagaga/doris-standalone
    container_name: doris
    restart: unless-stopped
    privileged: true
    ports:
      - "8030:8030" # FE Web UI / HTTP
      - "8040:8040" # BE HTTP
      - "9030:9030" # Protocolo MySQL
    volumes:
      - doris_data:/opt/apache-doris

  jobmanager:
    image: flink:1.20.2-scala_2.12-java17
    container_name: flink-jobmanager
    restart: unless-stopped
    command: jobmanager
    ports:
      - "8081:8081"
    environment:
      FLINK_PROPERTIES: |
        jobmanager.rpc.address: jobmanager
    volumes:
      - ./flink-lib:/opt/flink/usrlib           # JARs de conectores
      - ./flink-checkpoints:/shared/flink-checkpoints
    depends_on:
      - postgres

  taskmanager:
    image: flink:1.20.2-scala_2.12-java17
    container_name: flink-taskmanager
    restart: unless-stopped
    command: taskmanager
    environment:
      FLINK_PROPERTIES: |
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 16       # 16 slots = hasta 16 jobs en paralelo
        taskmanager.memory.process.size: 4096m
    volumes:
      - ./flink-lib:/opt/flink/usrlib
      - ./flink-checkpoints:/shared/flink-checkpoints
    depends_on:
      - jobmanager
      - postgres

  sql-client:
    image: flink:1.20.2-scala_2.12-java17
    container_name: flink-sql-client
    command: bin/sql-client.sh
    stdin_open: true
    tty: true
    environment:
      FLINK_PROPERTIES: |
        jobmanager.rpc.address: jobmanager
        rest.address: jobmanager
    volumes:
      - ./flink-lib:/opt/flink/usrlib
      - ./flink:/opt/flink/sql                   # Scripts SQL montados en el contenedor
      - ./flink-checkpoints:/shared/flink-checkpoints
    depends_on:
      - jobmanager
      - postgres

volumes:
  postgres16_data:
  doris_data:
```

</details>

---

### Fase 1 — Ingesta de Datos Fuente

Carga 9 datasets CSV crudos (~1.5M filas en total) en PostgreSQL 16. El cargador lee cada CSV, aplica conversiones de tipo y deduplicacion, y luego inserta los registros en lote respetando el orden de llaves foraneas.

```bash
python scripts/load_source_data.py
python scripts/fill_time_dimension.py
```

Los modelos ORM en `source/models.py` definen el esquema de las tablas fuente. Ejemplo con las tablas Order y OrderItem:

```python
class Order(Base):
    __tablename__ = "orders"

    order_id: Mapped[str] = mapped_column(primary_key=True)
    customer_id: Mapped[str] = mapped_column(ForeignKey("customers.customer_id"))
    order_status: Mapped[str]
    order_purchase_timestamp: Mapped[datetime]
    order_approved_at: Mapped[Optional[datetime]]
    order_delivered_carrier_date: Mapped[Optional[datetime]]
    order_delivered_customer_date: Mapped[Optional[datetime]]
    order_estimated_delivery_date: Mapped[Optional[datetime]]

    customer: Mapped["Customer"] = relationship(back_populates="orders")
    items: Mapped[list["OrderItem"]] = relationship(back_populates="order")


class OrderItem(Base):
    __tablename__ = "order_items"

    order_id: Mapped[str] = mapped_column(
        ForeignKey("orders.order_id"), primary_key=True
    )
    order_item_id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.product_id"))
    seller_id: Mapped[str] = mapped_column(ForeignKey("sellers.seller_id"))
    shipping_limit_date: Mapped[datetime]
    price: Mapped[float]
    freight_value: Mapped[float]
```

El script `source/reader.py` lee los CSVs, convierte tipos y filtra datos invalidos. Luego `scripts/load_source_data.py` inserta en lote:

```python
Base.metadata.drop_all(engine)
Base.metadata.create_all(engine)

(customers_dataframe, geolocation_dataframe, ...) = read_dataframes()

with Session(engine) as session:
    session.bulk_save_objects([
        Customer(
            customer_id=row["customer_id"],
            customer_unique_id=row["customer_unique_id"],
            customer_zip_code_prefix=row["customer_zip_code_prefix"],
            customer_city=row["customer_city"],
            customer_state=row["customer_state"],
        )
        for _, row in customers_dataframe.iterrows()
    ])
    session.commit()
    # ... repite para las 9 tablas en orden de dependencia
```

**Tablas fuente:** customers, sellers, products, product_category_name_translation, geolocations, orders, order_items, order_payments, order_reviews, dim_time

---

### Fase 2 — Publicacion CDC

Configura PostgreSQL para Change Data Capture. Habilita la replicacion logica en el WAL para que Flink pueda leer un stream de cambios via Debezium.

```bash
psql -h localhost -p 5435 -U postgres_user -d olist -f flink/postgresql_publication.sql
```

El script `flink/postgresql_publication.sql` establece la identidad de replica y crea la publicacion:

```sql
-- Establece REPLICA IDENTITY en todas las tablas para CDC
ALTER TABLE public.geolocations REPLICA IDENTITY DEFAULT;
ALTER TABLE public.customers REPLICA IDENTITY DEFAULT;
ALTER TABLE public.sellers REPLICA IDENTITY DEFAULT;
ALTER TABLE public.product_category_name_translation REPLICA IDENTITY DEFAULT;
ALTER TABLE public.products REPLICA IDENTITY DEFAULT;
ALTER TABLE public.orders REPLICA IDENTITY DEFAULT;
ALTER TABLE public.order_items REPLICA IDENTITY DEFAULT;
ALTER TABLE public.order_payments REPLICA IDENTITY DEFAULT;
ALTER TABLE public.order_reviews REPLICA IDENTITY DEFAULT;
ALTER TABLE public.dim_time REPLICA IDENTITY DEFAULT;

-- Crea la publicacion que Debezium consumira
-- (debezium.publication.autocreate.mode = disabled en Flink, por eso se crea manualmente)
DROP PUBLICATION IF EXISTS olist_publication;

CREATE PUBLICATION olist_publication FOR TABLE
    public.geolocations,
    public.customers,
    public.sellers,
    public.product_category_name_translation,
    public.products,
    public.orders,
    public.order_items,
    public.order_payments,
    public.order_reviews,
    public.dim_time;
```

---

### Fase 3 — Streaming con Flink

Apache Flink lee cambios incrementales de PostgreSQL via el conector CDC de Debezium y los escribe en las tablas staging de Doris con two-phase commit y semantica exactly-once.

```bash
python scripts/setup_flink.py

# O para ejecutar solo una tabla especifica:
python scripts/setup_flink.py orders.sql
```

Primero se cargan los JARs de conectores (`flink/setup.sql`):

```sql
ADD JAR '/opt/flink/usrlib/flink-doris-connector-1.20-26.0.0.jar';
ADD JAR '/opt/flink/usrlib/flink-sql-connector-postgres-cdc-3.5.0.jar';
```

Cada archivo en `flink/source_sink_tables/` define un par source/sink y un INSERT continuo. Ejemplo con la tabla `orders` (`flink/source_sink_tables/orders.sql`):

```sql
-- Tabla source: lee cambios de PostgreSQL via CDC
CREATE TABLE source_orders (
    order_id STRING,
    customer_id STRING,
    order_status STRING,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres',
    'port' = '5432',
    'username' = 'postgres_user',
    'password' = 'postgres_pass',
    'database-name' = 'olist',
    'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',     -- Plugin nativo de PostgreSQL
    'changelog-mode' = 'upsert',             -- Para tablas con llave unica
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'orders',
    'slot.name' = 'orders_flink_slot_1'      -- Slot WAL dedicado por tabla
);

-- Tabla sink: escribe en Doris
CREATE TABLE sink_orders (
    order_id VARCHAR(255),
    customer_id VARCHAR(255),
    order_status VARCHAR(255),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030',
    'benodes' = 'doris:8040',
    'username' = 'root',
    'password' = '',
    'sink.enable-2pc' = 'true',              -- Two-phase commit
    'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',      -- Modo streaming
    'sink.label-prefix' = 'sink_orders',
    'table.identifier' = 'olist.orders'
);

-- Configuracion de checkpointing
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

-- Job continuo: cada cambio en PostgreSQL se replica a Doris
INSERT INTO sink_orders
SELECT order_id, customer_id, order_status,
       order_purchase_timestamp, order_approved_at,
       order_delivered_carrier_date, order_delivered_customer_date,
       order_estimated_delivery_date
FROM source_orders;
```

El orquestador `scripts/setup_flink.py` concatena `setup.sql` con cada archivo de tabla y lo envia al SQL Client de Flink via Docker:

```python
CONTAINER = "flink-sql-client"
SETUP_SQL = "/opt/flink/sql/setup.sql"
TABLES_DIR = "/opt/flink/sql/source_sink_tables"

def run_sql_file(file_path: str):
    cmd = (
        f"cat {SETUP_SQL} <(echo '') {file_path} > /tmp/combined.sql "
        f"&& bin/sql-client.sh -f /tmp/combined.sql"
    )
    result = subprocess.run(
        ["docker", "exec", "-it", CONTAINER, "bash", "-lc", cmd],
        check=False,
    )
```

---

### Fase 4 — Creacion de Tablas en Doris

Crea la estructura dentro de Apache Doris: una capa staging (base `olist`) que replica las tablas fuente, y una capa analitica (base `warehouse`) con dimensiones y hechos siguiendo el esquema estrella de Kimball.

```bash
python scripts/setup_doris.py
```

**Paso 1 — Creacion de bases de datos** (`warehouse/setup/create_database.sql`):

```sql
CREATE DATABASE IF NOT EXISTS olist;
CREATE DATABASE IF NOT EXISTS warehouse;

-- Workload group para controlar concurrencia de carga
CREATE WORKLOAD GROUP IF NOT EXISTS warehouse_load
PROPERTIES (
  "max_concurrency" = "32",
  "max_queue_size" = "200",
  "queue_timeout" = "10000"
);

GRANT USAGE_PRIV ON WORKLOAD GROUP 'warehouse_load' TO 'flink'@'%';
```

**Paso 2 — Tablas staging** (`warehouse/staging/`). Ejemplo con `orders`:

```sql
-- Replica exacta de la tabla fuente, recibe datos de Flink
CREATE TABLE IF NOT EXISTS olist.orders (
    order_id VARCHAR(255) NOT NULL,
    customer_id VARCHAR(255) NOT NULL,
    order_status VARCHAR(255) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NULL
) UNIQUE KEY (order_id)
  DISTRIBUTED BY HASH (order_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

**Paso 3 — Tablas de dimension** (`warehouse/dimensions/`). Ejemplo con `dim_customer`:

```sql
-- Dimension con llave sustituta auto-incremental
CREATE TABLE IF NOT EXISTS warehouse.dim_customer (
    customer_id VARCHAR(64) NOT NULL COMMENT 'Llave natural del origen',
    customer_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
    customer_unique_id VARCHAR(64) NOT NULL,
    customer_zip_code_prefix VARCHAR(16) NOT NULL,
    customer_city VARCHAR(128) NOT NULL,
    customer_state VARCHAR(8) NOT NULL
) UNIQUE KEY (customer_id)
  DISTRIBUTED BY HASH (customer_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

Ejemplo con `dim_product` (incluye campos calculados):

```sql
CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_id VARCHAR(64) NOT NULL COMMENT 'Llave natural del origen',
    product_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
    product_english_category_name VARCHAR(256) NULL,
    product_category_name VARCHAR(256) NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,
    product_volume_cm3 INT NULL,                -- largo * alto * ancho
    product_density_g_per_cm3 DOUBLE NULL        -- peso / volumen
) UNIQUE KEY (product_id)
  DISTRIBUTED BY HASH (product_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

**Paso 4 — Tabla de hechos** (`warehouse/facts/fact_order_item.sql`):

```sql
-- Grano: una fila por articulo en una orden
CREATE TABLE IF NOT EXISTS warehouse.fact_order_item (
    order_id VARCHAR(64) NOT NULL COMMENT 'Dimension degenerada',
    order_item_id INT NOT NULL COMMENT 'Numero de linea dentro de la orden',
    order_item_fact_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
    product_key BIGINT NOT NULL COMMENT 'FK -> dim_product',
    customer_key BIGINT NOT NULL COMMENT 'FK -> dim_customer',
    seller_key BIGINT NOT NULL COMMENT 'FK -> dim_seller',
    order_status_key BIGINT NOT NULL COMMENT 'FK -> dim_order_status',
    order_date_key INT NULL COMMENT 'FK -> dim_time (YYYYMMDD)',
    item_price DECIMAL(12, 2) NOT NULL,
    freight_value DECIMAL(12, 2) NOT NULL
) UNIQUE KEY (order_id, order_item_id)
  DISTRIBUTED BY HASH (order_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

**Esquema estrella:**

```
                    dim_customer
                         |
dim_time ── fact_order_item ── dim_product
                    |    |
          dim_seller    dim_order_status
```

**Dimensiones:** dim_customer, dim_seller, dim_product (volumen y densidad), dim_geolocation, dim_order_status, dim_payment_type, dim_time

**Hechos:** fact_order_item — medidas: `item_price` y `freight_value`

---

### Fase 5 — Poblacion del Warehouse (ETL)

Puebla el esquema estrella transformando datos de la capa staging en dimensiones conformadas y la tabla de hechos.

```bash
python scripts/populate_warehouse.py
```

**Paso 1 — Inserts de dimensiones** (`warehouse/etl/`). Ejemplo con `dim_customer`:

```sql
-- Extrae clientes distintos de staging, filtrando NULLs
INSERT INTO warehouse.dim_customer (
    customer_id, customer_unique_id,
    customer_zip_code_prefix, customer_city, customer_state
)
SELECT DISTINCT
    customers.customer_id,
    customers.customer_unique_id,
    customers.customer_zip_code_prefix,
    customers.customer_city,
    customers.customer_state
FROM olist.customers AS customers
WHERE customers.customer_unique_id IS NOT NULL
  AND customers.customer_zip_code_prefix IS NOT NULL
  AND customers.customer_city IS NOT NULL
  AND customers.customer_state IS NOT NULL;
```

Ejemplo con `dim_product` (campos calculados):

```sql
-- Calcula volumen y densidad a partir de dimensiones fisicas
INSERT INTO warehouse.dim_product (
    product_id, product_english_category_name, product_category_name,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm,
    product_volume_cm3, product_density_g_per_cm3
)
SELECT DISTINCT
    products.product_id,
    pcnt.product_category_name_english,
    products.product_category_name,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm,
    products.product_length_cm * products.product_height_cm * products.product_width_cm,
    CAST(products.product_weight_g AS DOUBLE) / (
        products.product_length_cm * products.product_height_cm * products.product_width_cm
    )
FROM olist.products AS products
JOIN olist.product_category_name_translation AS pcnt
    ON products.product_category_name = pcnt.product_category_name
WHERE products.product_weight_g > 0
  AND products.product_length_cm > 0
  AND products.product_height_cm > 0
  AND products.product_width_cm > 0;
```

**Paso 2 — Insert de la tabla de hechos** (`warehouse/etl/insert_fact_table.sql`):

```sql
-- Resuelve llaves sustitutas via JOINs y convierte timestamp a date_id
INSERT INTO warehouse.fact_order_item (
    order_id, order_item_id, product_key, customer_key,
    seller_key, order_status_key, order_date_key,
    item_price, freight_value
)
SELECT
    order_items.order_id,
    order_items.order_item_id,
    COALESCE(dim_product.product_key, 0),
    COALESCE(dim_customer.customer_key, 0),
    COALESCE(dim_seller.seller_key, 0),
    COALESCE(dim_order_status.order_status_key, 0),
    CAST(DATE_FORMAT(orders.order_purchase_timestamp, '%%Y%%m%%d') AS INT),
    order_items.price,
    order_items.freight_value
FROM olist.order_items AS order_items
JOIN olist.orders AS orders
    ON order_items.order_id = orders.order_id
JOIN warehouse.dim_customer AS dim_customer
    ON orders.customer_id = dim_customer.customer_id
LEFT JOIN warehouse.dim_product AS dim_product
    ON order_items.product_id = dim_product.product_id
LEFT JOIN warehouse.dim_seller AS dim_seller
    ON order_items.seller_id = dim_seller.seller_id
LEFT JOIN warehouse.dim_order_status AS dim_order_status
    ON orders.order_status = dim_order_status.order_status;
```

El script `scripts/populate_warehouse.py` ejecuta los inserts en orden de dependencia:

```python
ETL_DIR = PROJECT_ROOT / "warehouse" / "etl"

sql_file_paths = [
    ETL_DIR / "insert_dim_customer.sql",
    ETL_DIR / "insert_dim_seller.sql",
    ETL_DIR / "insert_dim_geolocation.sql",
    ETL_DIR / "insert_dim_payment_type.sql",
    ETL_DIR / "insert_dim_order_status.sql",
    ETL_DIR / "insert_dim_product.sql",
    ETL_DIR / "insert_fact_table.sql",       # Siempre al final
]

with engine.begin() as connection:
    for sql_file_path in sql_file_paths:
        sql_content = sql_file_path.read_text(encoding="utf-8")
        for statement in split_sql_statements(sql_content):
            connection.exec_driver_sql(statement)
```

---

### Fase 6 — Analitica

El esquema estrella completo se consulta a traves de vistas desnormalizadas y se conecta a Apache Superset para dashboards.

```bash
# Instalar dialecto de Doris en Superset
./scripts/superset_setup.ps1
```

**Query desnormalizado completo** (`warehouse/queries/fact_order_item_full.sql`):

```sql
-- Vista plana con todos los atributos de dimension para BI
SELECT
    f.order_id,
    f.order_item_id,
    f.item_price,
    f.freight_value,
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    s.seller_id,
    s.seller_city,
    s.seller_state,
    p.product_id,
    p.product_english_category_name,
    p.product_category_name,
    p.product_weight_g,
    p.product_volume_cm3,
    p.product_density_g_per_cm3,
    os.order_status,
    t.full_date AS order_date,
    t.year AS order_year,
    t.quarter AS order_quarter,
    t.month AS order_month,
    t.day_name AS order_day_name,
    t.is_weekend AS order_is_weekend
FROM warehouse.fact_order_item AS f
JOIN warehouse.dim_customer AS c ON f.customer_key = c.customer_key
JOIN warehouse.dim_seller AS s ON f.seller_key = s.seller_key
JOIN warehouse.dim_product AS p ON f.product_key = p.product_key
JOIN warehouse.dim_order_status AS os ON f.order_status_key = os.order_status_key
LEFT JOIN warehouse.dim_time AS t ON f.order_date_key = t.date_id;
```

**Metricas definidas para dashboards** (ver `warehouse/bi-options.md`):

| Metrica | Formula |
|---------|---------|
| Ingreso bruto | `SUM(item_price)` |
| Ingreso por flete | `SUM(freight_value)` |
| Ingreso total | `SUM(item_price + freight_value)` |
| Total de ordenes | `COUNT(DISTINCT order_id)` |
| Valor promedio por orden | `ingreso_total / total_ordenes` |
| Ratio de flete | `SUM(freight_value) / SUM(item_price + freight_value)` |

---

## Estructura del Proyecto

```
pipeline-1/
├── docker-compose.yaml        # PostgreSQL, Doris, Flink (JobManager + TaskManager + SQL Client)
├── requirements.txt           # Dependencias de Python
├── .gitignore
│
├── scripts/                   # Todos los scripts ejecutables
│   ├── load_source_data.py    # Fase 1: CSV → PostgreSQL
│   ├── fill_time_dimension.py # Fase 1: Generar dimension de tiempo
│   ├── setup_flink.py/.ps1    # Fase 3: Enviar jobs SQL a Flink
│   ├── setup_doris.py         # Fase 4: Crear tablas en Doris
│   ├── populate_warehouse.py  # Fase 5: Ejecutar inserts ETL
│   ├── cancel_flink_jobs.py   # Utilidad: cancelar jobs de Flink en ejecucion
│   ├── install.sh/.ps1        # Setup del entorno
│   ├── install_docker.sh      # Instalacion de Docker (Linux)
│   └── superset_setup.ps1     # Fase 6: Dialecto de Superset
│
├── source/                    # Capa fuente PostgreSQL (modelos ORM)
│   ├── base.py                # SQLAlchemy DeclarativeBase
│   ├── models.py              # 9 modelos ORM de tablas fuente
│   ├── reader.py              # Lector de CSV con conversion de tipos
│   └── time_dimension.py      # Modelo ORM TimeDimension
│
├── raw_data/                  # 9 datasets CSV de Olist (~122 MB)
│
├── flink/                     # Capa de streaming Flink
│   ├── setup.sql              # Carga de JARs
│   ├── postgresql_publication.sql  # Setup de publicacion CDC
│   └── source_sink_tables/    # 10 definiciones de tablas source/sink
│
├── warehouse/                 # Capa warehouse en Doris
│   ├── setup/                 # Creacion de base de datos y workload group
│   ├── staging/               # DDL de tablas staging (olist.*)
│   ├── dimensions/            # DDL de tablas de dimension (warehouse.*)
│   ├── facts/                 # DDL de tablas de hechos (warehouse.*)
│   ├── etl/                   # SQL de INSERT/transformacion
│   ├── queries/               # Queries analiticos
│   └── bi-options.md          # Guia de diseno de dashboards
│
├── flink-lib/                 # JARs de conectores Flink (ignorados por git)
└── flink-checkpoints/         # Estado de checkpoints de Flink (ignorado por git)
```

## Servicios

| Servicio | Puerto | Proposito |
|----------|--------|-----------|
| PostgreSQL 16 | 5435 | Base de datos transaccional fuente |
| Doris FE | 8030 | Web UI del frontend / API HTTP |
| Doris BE | 8040 | HTTP del backend |
| Doris MySQL | 9030 | Protocolo MySQL (queries y DDL) |
| Flink JobManager | 8081 | Dashboard de Flink / API REST |

## Inicio Rapido

```bash
# 0. Levantar infraestructura
docker compose up -d

# 1. Instalar dependencias de Python
./scripts/install.sh        # Linux/Mac
./scripts/install.ps1       # Windows

# 2. Fase 1: Cargar datos fuente
python scripts/load_source_data.py
python scripts/fill_time_dimension.py

# 3. Fase 2: Configurar CDC (ejecutar en psql)
psql -h localhost -p 5435 -U postgres_user -d olist -f flink/postgresql_publication.sql

# 4. Fase 4: Crear tablas en Doris
python scripts/setup_doris.py

# 5. Fase 3: Iniciar jobs de streaming en Flink
python scripts/setup_flink.py

# 6. Fase 5: Poblar warehouse (despues de que los datos se hayan sincronizado)
python scripts/populate_warehouse.py
```

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100K ordenes de 2016 a 2018 a traves de multiples marketplaces en Brasil.
