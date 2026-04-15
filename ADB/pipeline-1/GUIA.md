# Guia: De Flink CDC a Superset

Esta guia cubre las fases del pipeline que van desde la captura de cambios en tiempo real con Apache Flink, pasando por la construccion del data warehouse en Apache Doris, hasta la visualizacion en Apache Superset.

**Prerequisitos:** La base de datos PostgreSQL ya tiene las 10 tablas cargadas con datos del dataset de Olist (esto ya se cubrio en la presentacion anterior).

### Infraestructura (docker-compose.yaml)

Todos los servicios se levantan con `docker compose up -d`:

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
      - wal_level=logical
      - -c
      - max_replication_slots=32
      - -c
      - max_wal_senders=32

  doris:
    image: yagagagaga/doris-standalone
    container_name: doris
    restart: unless-stopped
    privileged: true
    ports:
      - "8030:8030"   # FE Web UI / HTTP
      - "8040:8040"   # BE HTTP
      - "9030:9030"   # Protocolo MySQL
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
      - ./flink-lib:/opt/flink/usrlib
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
        taskmanager.numberOfTaskSlots: 16
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
      - ./flink:/opt/flink/sql
      - ./flink-checkpoints:/shared/flink-checkpoints
    depends_on:
      - jobmanager
      - postgres

volumes:
  postgres16_data:
  doris_data:
```

</details>

| Servicio | Puerto | Proposito |
|----------|--------|-----------|
| PostgreSQL 16 | 5435 | Base de datos transaccional fuente |
| Doris FE | 8030 | Web UI del frontend / API HTTP |
| Doris BE | 8040 | HTTP del backend |
| Doris MySQL | 9030 | Protocolo MySQL (queries y DDL) |
| Flink JobManager | 8081 | Dashboard de Flink / API REST |

---

## Indice

1. [Introduccion a Change Data Capture (CDC)](#1-introduccion-a-change-data-capture-cdc)
2. [Apache Flink y Flink SQL](#2-apache-flink-y-flink-sql)
3. [Configuracion de CDC en PostgreSQL](#3-configuracion-de-cdc-en-postgresql)
4. [Jobs de streaming: PostgreSQL a Doris](#4-jobs-de-streaming-postgresql-a-doris)
5. [Apache Doris como OLAP](#5-apache-doris-como-olap)
6. [Modelado dimensional (Kimball)](#6-modelado-dimensional-kimball)
7. [Creacion de tablas en Doris](#7-creacion-de-tablas-en-doris)
8. [ETL: Poblar el esquema estrella](#8-etl-poblar-el-esquema-estrella)
9. [Visualizacion con Apache Superset](#9-visualizacion-con-apache-superset)

---

## 1. Introduccion a Change Data Capture (CDC)

### Que es CDC

Change Data Capture es una tecnica que identifica y captura los cambios (inserts, updates, deletes) que ocurren en una base de datos, y los entrega como un stream de eventos a otros sistemas.

En lugar de hacer consultas periodicas ("polling") para detectar que cambio, CDC lee directamente del log de transacciones de la base de datos, lo cual tiene varias ventajas:

| Caracteristica | Polling (consultas periodicas) | CDC (log de transacciones) |
|----------------|-------------------------------|---------------------------|
| Latencia | Alta (depende del intervalo) | Baja (casi tiempo real) |
| Carga en la DB fuente | Alta (queries constantes) | Minima (lee el log existente) |
| Detecta deletes | Dificil | Si, nativamente |
| Orden de eventos | No garantizado | Garantizado (orden del log) |
| Complejidad | Baja | Media (requiere configuracion) |

### CDC en PostgreSQL: Replicacion Logica

PostgreSQL implementa CDC a traves de su **Write-Ahead Log (WAL)**. El WAL es un registro secuencial de todas las modificaciones a los datos — PostgreSQL lo usa internamente para garantizar durabilidad y recuperacion ante fallos.

Cuando habilitamos `wal_level=logical`, PostgreSQL escribe informacion adicional en el WAL que permite decodificar los cambios a nivel de fila:

```
Transaccion → WAL (wal_level=logical) → Slot de replicacion → Consumidor (Flink/Debezium)
```

Los conceptos clave son:

- **WAL (Write-Ahead Log):** Log donde PostgreSQL registra cada cambio antes de aplicarlo a los archivos de datos.
- **Slot de replicacion:** Un "cursor" con nombre que marca hasta donde un consumidor ha leido el WAL. PostgreSQL no descarta entradas del WAL que un slot aun no ha consumido.
- **Publicacion:** Define que tablas son visibles para los consumidores de replicacion logica.
- **Plugin de decodificacion:** Traduce el WAL binario a un formato legible. Usamos `pgoutput`, el plugin nativo de PostgreSQL.

### Debezium

Debezium es una plataforma open-source de CDC que se conecta a bases de datos y convierte sus logs de transacciones en streams de eventos. En nuestro caso, el conector `flink-sql-connector-postgres-cdc` integra Debezium directamente dentro de Flink, sin necesidad de un cluster de Kafka intermedio.

Flujo de datos:

```
PostgreSQL WAL → pgoutput → Debezium (embebido en Flink) → Flink Source Table
```

---

## 2. Apache Flink y Flink SQL

### Que es Apache Flink

Apache Flink es un motor de procesamiento de streams distribuido. A diferencia de herramientas de procesamiento por lotes (como Spark tradicional), Flink esta disenado desde su base para procesar datos en tiempo real, registro por registro.

### Arquitectura de nuestro cluster Flink

```
┌──────────────────┐     ┌───────────────────┐
│   JobManager     │────▶│   TaskManager      │
│   (puerto 8081)  │     │   (16 task slots)  │
│                  │     │   (4 GB RAM)        │
│   - Planifica    │     │                     │
│   - Coordina     │     │   - Ejecuta tareas  │
│   - Checkpoints  │     │   - Lee de sources   │
└──────────────────┘     │   - Escribe a sinks  │
                         └───────────────────┘
         ▲
         │
┌──────────────────┐
│   SQL Client     │
│                  │
│   - Envia SQL    │
│   - Define jobs  │
└──────────────────┘
```

- **JobManager:** Cerebro del cluster. Recibe los jobs, los planifica y coordina los checkpoints.
- **TaskManager:** Ejecuta el trabajo real. Tiene 16 "task slots", lo que significa que puede correr hasta 16 tareas en paralelo.
- **SQL Client:** Interfaz para enviar sentencias SQL que se convierten en jobs de streaming.

### Flink SQL

Flink SQL permite definir pipelines de streaming usando SQL estandar. Cada `INSERT INTO ... SELECT FROM` se convierte en un job continuo que procesa datos en tiempo real.

Un job de Flink SQL tiene tres componentes:

1. **Source table:** De donde lee los datos (en nuestro caso, PostgreSQL via CDC).
2. **Sink table:** A donde escribe los datos (en nuestro caso, Apache Doris).
3. **Query:** La transformacion SQL entre source y sink.

### Checkpointing y Exactly-Once

Flink garantiza **exactly-once semantics** — cada registro se procesa exactamente una vez, incluso ante fallos. Lo logra con un mecanismo llamado **checkpointing**:

1. Periodicamente (cada 10 segundos en nuestra configuracion), Flink toma un "snapshot" del estado de cada operador.
2. Si ocurre un fallo, Flink restaura el estado desde el ultimo checkpoint exitoso y reprocesa solo lo necesario.
3. Con **two-phase commit** habilitado en el sink, Flink coordina con Doris para que los datos solo se hagan visibles cuando el checkpoint completa exitosamente.

```sql
-- Configuracion de checkpointing en cada job
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';
```

---

## 3. Configuracion de CDC en PostgreSQL

### Paso 1: Habilitar replicacion logica

Esto ya esta configurado en la configuracion de Docker Compose. PostgreSQL arranca con:

```yaml
command:
  - postgres
  - -c
  - wal_level=logical          # Habilita decodificacion logica del WAL
  - -c
  - max_replication_slots=32   # Un slot por tabla + margen
  - -c
  - max_wal_senders=32         # Conexiones de replicacion permitidas
```

Para verificar que la configuracion esta activa:

```sql
-- Conectar a PostgreSQL
psql -h localhost -p 5435 -U postgres_user -d olist

-- Verificar wal_level
SHOW wal_level;
-- Debe mostrar: logical
```

### Paso 2: Configurar identidad de replica

La identidad de replica le dice a PostgreSQL que informacion incluir en el WAL para cada cambio. Con `DEFAULT`, incluye la llave primaria, que es suficiente para identificar que fila cambio:

```sql
ALTER TABLE public.customers REPLICA IDENTITY DEFAULT;
ALTER TABLE public.orders REPLICA IDENTITY DEFAULT;
ALTER TABLE public.order_items REPLICA IDENTITY DEFAULT;
ALTER TABLE public.order_payments REPLICA IDENTITY DEFAULT;
ALTER TABLE public.order_reviews REPLICA IDENTITY DEFAULT;
ALTER TABLE public.products REPLICA IDENTITY DEFAULT;
ALTER TABLE public.sellers REPLICA IDENTITY DEFAULT;
ALTER TABLE public.geolocations REPLICA IDENTITY DEFAULT;
ALTER TABLE public.product_category_name_translation REPLICA IDENTITY DEFAULT;
ALTER TABLE public.dim_time REPLICA IDENTITY DEFAULT;
```

### Paso 3: Crear la publicacion

La publicacion define que tablas seran visibles para los consumidores de CDC:

```sql
DROP PUBLICATION IF EXISTS olist_publication;

CREATE PUBLICATION olist_publication FOR TABLE
    public.customers,
    public.orders,
    public.order_items,
    public.order_payments,
    public.order_reviews,
    public.products,
    public.sellers,
    public.geolocations,
    public.product_category_name_translation,
    public.dim_time;
```

Para verificar:

```sql
-- Ver publicaciones existentes
SELECT * FROM pg_publication;

-- Ver que tablas estan en la publicacion
SELECT * FROM pg_publication_tables WHERE pubname = 'olist_publication';
```

**Ejecutar todo de una vez** (guardando los comandos anteriores en un archivo `.sql` y pasandolo a `psql`):

```bash
psql -h localhost -p 5435 -U postgres_user -d olist -f publicacion.sql
```

---

## 4. Jobs de streaming: PostgreSQL a Doris

### Conectores necesarios

Flink necesita dos JARs adicionales que se montan en `/opt/flink/usrlib`:

| JAR | Version | Funcion |
|-----|---------|---------|
| `flink-sql-connector-postgres-cdc` | 3.5.0 | Conector CDC para leer cambios de PostgreSQL via Debezium |
| `flink-doris-connector` | 1.20-26.0.0 | Conector para escribir en Apache Doris |

Se cargan al inicio de cada job con:

```sql
ADD JAR '/opt/flink/usrlib/flink-doris-connector-1.20-26.0.0.jar';
ADD JAR '/opt/flink/usrlib/flink-sql-connector-postgres-cdc-3.5.0.jar';
```

### Anatomia de un job de streaming

Cada job de streaming sigue el mismo patron. Usemos la tabla `customers` como ejemplo:

**1. Tabla source (PostgreSQL CDC):**

```sql
CREATE TABLE source_customers (
    customer_id STRING,
    customer_unique_id STRING,
    customer_zip_code_prefix STRING,
    customer_city STRING,
    customer_state STRING,
    PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres',                       -- Nombre del contenedor Docker
    'port' = '5432',                               -- Puerto interno (no el 5435 expuesto)
    'username' = 'postgres_user',
    'password' = 'postgres_pass',
    'database-name' = 'olist',
    'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',           -- Plugin nativo de PostgreSQL
    'changelog-mode' = 'upsert',                   -- Genera upserts (insert o update)
    'scan.incremental.snapshot.enabled' = 'true',   -- Snapshot incremental por chunks
    'scan.incremental.snapshot.chunk.size' = '2000', -- 2000 filas por chunk
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled', -- Usamos publicacion manual
    'table-name' = 'customers',
    'slot.name' = 'customers_flink_slot_1'         -- Slot WAL unico por tabla
);
```

Parametros importantes:

- **`changelog-mode = upsert`:** Para tablas con llave primaria, los cambios se representan como upserts (insert si no existe, update si existe).
- **`scan.incremental.snapshot`:** En lugar de leer toda la tabla de golpe, la lee en chunks de 2000 filas. Esto evita bloquear la base de datos.
- **`slot.name`:** Cada tabla necesita su propio slot de replicacion. El slot guarda el punto hasta donde Flink ha leido, para que al reiniciar no pierda datos.

**2. Tabla sink (Doris):**

```sql
CREATE TABLE sink_customers (
    customer_id VARCHAR(255),
    customer_unique_id VARCHAR(255),
    customer_zip_code_prefix VARCHAR(255),
    customer_city VARCHAR(255),
    customer_state VARCHAR(255),
    PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030',                      -- Frontend de Doris (HTTP)
    'benodes' = 'doris:8040',                      -- Backend de Doris (HTTP)
    'username' = 'root',
    'password' = '',
    'sink.enable-2pc' = 'true',                    -- Two-phase commit
    'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',  -- Datos visibles despues del commit
    'sink.enable.batch-mode' = 'false',            -- Streaming, no batch
    'sink.label-prefix' = 'sink_customers',        -- Prefijo unico para transacciones
    'table.identifier' = 'olist.customers'         -- Base.tabla destino en Doris
);
```

Parametros importantes:

- **`sink.enable-2pc = true`:** Two-phase commit. Flink pre-escribe los datos y solo los hace visibles cuando el checkpoint completa. Si el job falla antes del checkpoint, los datos pre-escritos se descartan.
- **`sink.properties.group_commit = sync_mode`:** Doris agrupa multiples writes en un solo commit para mejor rendimiento, y confirma de forma sincrona.
- **`sink.label-prefix`:** Doris usa labels para identificar cargas de datos. Cada label debe ser unico.

**3. Configuracion de checkpointing y el INSERT continuo:**

```sql
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

-- Este INSERT se convierte en un job continuo — no termina nunca
INSERT INTO sink_customers
SELECT
    customer_id, customer_unique_id,
    customer_zip_code_prefix, customer_city, customer_state
FROM source_customers;
```

### Todos los jobs de streaming

El ejemplo anterior fue para la tabla `customers`. Los demas 9 jobs siguen el mismo patron source/sink/INSERT. Aqui estan completos:

<details>
<summary>Job: orders</summary>

```sql
DROP TABLE IF EXISTS source_orders;

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
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'orders',
    'slot.name' = 'orders_flink_slot_1'
);

DROP TABLE IF EXISTS sink_orders;

CREATE TABLE sink_orders (
    order_id VARCHAR(255), customer_id VARCHAR(255),
    order_status VARCHAR(255),
    order_purchase_timestamp TIMESTAMP, order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_orders',
    'table.identifier' = 'olist.orders'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_orders
SELECT order_id, customer_id, order_status,
       order_purchase_timestamp, order_approved_at,
       order_delivered_carrier_date, order_delivered_customer_date,
       order_estimated_delivery_date
FROM source_orders;
```

</details>

<details>
<summary>Job: order_items</summary>

```sql
DROP TABLE IF EXISTS source_order_items;

CREATE TABLE source_order_items (
    order_id STRING, order_item_id INT,
    product_id STRING, seller_id STRING,
    shipping_limit_date TIMESTAMP,
    price DOUBLE, freight_value DOUBLE,
    PRIMARY KEY (order_id, order_item_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'order_items',
    'slot.name' = 'order_items_flink_slot_1'
);

DROP TABLE IF EXISTS sink_order_items;

CREATE TABLE sink_order_items (
    order_id VARCHAR(255), order_item_id INT,
    product_id VARCHAR(255), seller_id VARCHAR(255),
    shipping_limit_date TIMESTAMP,
    price DOUBLE, freight_value DOUBLE,
    PRIMARY KEY (order_id, order_item_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_order_items',
    'table.identifier' = 'olist.order_items'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_order_items
SELECT order_id, order_item_id, product_id, seller_id,
       shipping_limit_date, price, freight_value
FROM source_order_items;
```

</details>

<details>
<summary>Job: order_payments</summary>

```sql
DROP TABLE IF EXISTS source_order_payments;

CREATE TABLE source_order_payments (
    order_id STRING, payment_sequential INT,
    payment_type STRING, payment_installments INT,
    payment_value DOUBLE,
    PRIMARY KEY (order_id, payment_sequential) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'order_payments',
    'slot.name' = 'order_payments_flink_slot_1'
);

DROP TABLE IF EXISTS sink_order_payments;

CREATE TABLE sink_order_payments (
    order_id VARCHAR(255), payment_sequential INT,
    payment_type VARCHAR(255), payment_installments INT,
    payment_value DOUBLE,
    PRIMARY KEY (order_id, payment_sequential) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_order_payments',
    'table.identifier' = 'olist.order_payments'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_order_payments
SELECT order_id, payment_sequential, payment_type,
       payment_installments, payment_value
FROM source_order_payments;
```

</details>

<details>
<summary>Job: order_reviews (con limpieza de caracteres especiales)</summary>

```sql
DROP TABLE IF EXISTS source_order_reviews;

CREATE TABLE source_order_reviews (
    review_id STRING, order_id STRING,
    review_score INT,
    review_comment_title STRING,
    review_comment_message STRING,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'order_reviews',
    'slot.name' = 'order_reviews_flink_slot_1'
);

DROP TABLE IF EXISTS sink_order_reviews;

CREATE TABLE sink_order_reviews (
    review_id VARCHAR(255), order_id VARCHAR(255),
    review_score INT,
    review_comment_title VARCHAR(255),
    review_comment_message VARCHAR(255),
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_order_reviews',
    'table.identifier' = 'olist.order_reviews'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

-- Nota: los campos de texto se limpian de tabs, saltos de linea y retornos de carro
-- porque Doris no acepta esos caracteres en carga streaming
INSERT INTO sink_order_reviews
SELECT
    CAST(review_id AS VARCHAR(255)),
    CAST(order_id AS VARCHAR(255)),
    CAST(review_score AS INT),
    CAST(REPLACE(REPLACE(REPLACE(
        CAST(review_comment_title AS STRING), CHR(9), ' '), CHR(10), ' '), CHR(13), ' '
    ) AS VARCHAR(255)),
    CAST(REPLACE(REPLACE(REPLACE(
        CAST(review_comment_message AS STRING), CHR(9), ' '), CHR(10), ' '), CHR(13), ' '
    ) AS VARCHAR(255)),
    review_creation_date,
    review_answer_timestamp
FROM source_order_reviews;
```

</details>

<details>
<summary>Job: products</summary>

```sql
DROP TABLE IF EXISTS source_products;

CREATE TABLE source_products (
    product_id STRING, product_category_name STRING,
    product_name_length INT, product_description_length INT,
    product_photos_qty INT, product_weight_g INT,
    product_length_cm INT, product_height_cm INT, product_width_cm INT,
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'products',
    'slot.name' = 'products_flink_slot_1'
);

DROP TABLE IF EXISTS sink_products;

CREATE TABLE sink_products (
    product_id VARCHAR(255), product_category_name VARCHAR(255),
    product_name_length INT, product_description_length INT,
    product_photos_qty INT, product_weight_g INT,
    product_length_cm INT, product_height_cm INT, product_width_cm INT,
    PRIMARY KEY (product_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_products',
    'table.identifier' = 'olist.products'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_products
SELECT product_id, product_category_name,
       product_name_length, product_description_length,
       product_photos_qty, product_weight_g,
       product_length_cm, product_height_cm, product_width_cm
FROM source_products;
```

</details>

<details>
<summary>Job: sellers</summary>

```sql
DROP TABLE IF EXISTS source_sellers;

CREATE TABLE source_sellers (
    seller_id STRING, seller_zip_code_prefix STRING,
    seller_city STRING, seller_state STRING,
    PRIMARY KEY (seller_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'sellers',
    'slot.name' = 'sellers_flink_slot_1'
);

DROP TABLE IF EXISTS sink_sellers;

CREATE TABLE sink_sellers (
    seller_id VARCHAR(255), seller_zip_code_prefix VARCHAR(255),
    seller_city VARCHAR(255), seller_state VARCHAR(255),
    PRIMARY KEY (seller_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_sellers',
    'table.identifier' = 'olist.sellers'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_sellers
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM source_sellers;
```

</details>

<details>
<summary>Job: geolocations</summary>

```sql
DROP TABLE IF EXISTS source_geolocations;

CREATE TABLE source_geolocations (
    geolocation_zip_code_prefix STRING,
    geolocation_lat DOUBLE, geolocation_lng DOUBLE,
    geolocation_city STRING, geolocation_state STRING,
    PRIMARY KEY (geolocation_lat, geolocation_lng) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'table-name' = 'geolocations',
    'slot.name' = 'geolocations_flink_slot_1',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled'
);

DROP TABLE IF EXISTS sink_geolocations;

CREATE TABLE sink_geolocations (
    geolocation_zip_code_prefix VARCHAR(255),
    geolocation_lat DOUBLE, geolocation_lng DOUBLE,
    geolocation_city VARCHAR(255), geolocation_state VARCHAR(255),
    PRIMARY KEY (geolocation_lat, geolocation_lng) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_geolocations',
    'table.identifier' = 'olist.geolocations'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_geolocations
SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
       geolocation_city, geolocation_state
FROM source_geolocations;
```

</details>

<details>
<summary>Job: product_category_name_translation</summary>

```sql
DROP TABLE IF EXISTS source_product_category_name_translation;

CREATE TABLE source_product_category_name_translation (
    product_category_name STRING,
    product_category_name_english STRING,
    PRIMARY KEY (product_category_name) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'product_category_name_translation',
    'slot.name' = 'product_category_name_translation_flink_slot_1'
);

DROP TABLE IF EXISTS sink_product_category_name_translation;

CREATE TABLE sink_product_category_name_translation (
    product_category_name VARCHAR(255),
    product_category_name_english VARCHAR(255),
    PRIMARY KEY (product_category_name) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_product_category_name_translation',
    'table.identifier' = 'olist.product_category_name_translation'
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_product_category_name_translation
SELECT product_category_name, product_category_name_english
FROM source_product_category_name_translation;
```

</details>

<details>
<summary>Job: dim_time (escribe en warehouse.dim_time, no en olist)</summary>

```sql
DROP TABLE IF EXISTS source_dim_time;

CREATE TABLE source_dim_time (
    date_id INT, full_date DATE,
    `year` INT, `quarter` INT, `month` INT, `day` INT,
    day_of_week INT, day_name STRING,
    week_of_year_iso INT, is_weekend BOOLEAN,
    PRIMARY KEY (date_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = 'postgres', 'port' = '5432',
    'username' = 'postgres_user', 'password' = 'postgres_pass',
    'database-name' = 'olist', 'schema-name' = 'public',
    'decoding.plugin.name' = 'pgoutput',
    'changelog-mode' = 'upsert',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '2000',
    'scan.snapshot.fetch.size' = '200',
    'debezium.publication.name' = 'olist_publication',
    'debezium.publication.autocreate.mode' = 'disabled',
    'table-name' = 'dim_time',
    'slot.name' = 'dim_time_flink_slot_1'
);

DROP TABLE IF EXISTS sink_dim_time;

CREATE TABLE sink_dim_time (
    date_id INT, full_date DATE,
    `year` INT, `quarter` INT, `month` INT, `day` INT,
    day_of_week INT, day_name VARCHAR(255),
    week_of_year_iso INT, is_weekend BOOLEAN,
    PRIMARY KEY (date_id) NOT ENFORCED
) WITH (
    'connector' = 'doris',
    'fenodes' = 'doris:8030', 'benodes' = 'doris:8040',
    'username' = 'root', 'password' = '',
    'sink.enable-2pc' = 'true', 'sink.max-retries' = '10',
    'sink.properties.group_commit' = 'sync_mode',
    'sink.enable.batch-mode' = 'false',
    'sink.label-prefix' = 'sink_dim_time',
    'table.identifier' = 'warehouse.dim_time'  -- Va directo al warehouse, no a staging
);

SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.storage' = 'filesystem';
SET 'execution.checkpointing.dir' = 'file:///shared/flink-checkpoints';

INSERT INTO sink_dim_time
SELECT date_id, full_date, `year`, `quarter`, `month`, `day`,
       day_of_week, day_name, week_of_year_iso, is_weekend
FROM source_dim_time;
```

</details>

### Ejecutar los jobs

El script de automatizacion ejecuta los jobs de Flink. Por cada tabla:

1. Concatena el SQL de carga de JARs con la definicion de la tabla.
2. Envia el SQL combinado al contenedor `flink-sql-client` via Docker.
3. Flink crea un job continuo que replica los cambios en tiempo real.

<details>
<summary>Script de automatizacion de Flink (Python)</summary>

```python
"""
Run all Flink SQL table scripts.
Concatenates JAR loading SQL with each table definition and
executes them via the Flink SQL client inside the Docker container.
"""

import subprocess
import sys

CONTAINER = "flink-sql-client"
SETUP_SQL = "/opt/flink/sql/setup.sql"
TABLES_DIR = "/opt/flink/sql/source_sink_tables"


def run_sql_file(file_path: str):
    """Concatenate setup SQL with table file and execute via Flink SQL client."""
    print(f"Running {file_path} ...")
    cmd = (
        f"cat {SETUP_SQL} <(echo '') {file_path} > /tmp/combined.sql "
        f"&& bin/sql-client.sh -f /tmp/combined.sql"
    )
    result = subprocess.run(
        ["docker", "exec", "-it", CONTAINER, "bash", "-lc", cmd],
        check=False,
    )
    if result.returncode != 0:
        print(f"  FAILED (exit code {result.returncode})")
    else:
        print("  OK")
    return result.returncode


def main():
    # If a specific file is passed as argument, run only that one
    if len(sys.argv) > 1:
        for filename in sys.argv[1:]:
            file_path = f"{TABLES_DIR}/{filename}"
            run_sql_file(file_path)
        return

    # Otherwise, run all SQL files in the tables directory
    result = subprocess.run(
        ["docker", "exec", CONTAINER, "bash", "-c", f"ls {TABLES_DIR}/*.sql"],
        capture_output=True,
        text=True,
        check=True,
    )

    sql_files = [f.strip() for f in result.stdout.strip().splitlines() if f.strip()]

    for file_path in sql_files:
        run_sql_file(file_path)

    print("\nDone.")


if __name__ == "__main__":
    main()
```

</details>

```bash
# Ejecutar todos los jobs (10 tablas)
python setup_flink.py

# Ejecutar solo una tabla especifica
python setup_flink.py customers.sql

# Verificar jobs en ejecucion: abrir http://localhost:8081
```

### Verificar que los jobs estan corriendo

1. **Dashboard de Flink:** Abrir `http://localhost:8081` en el navegador. Deben aparecer 10 jobs en estado "RUNNING".
2. **Verificar datos en Doris:**

```bash
# Conectar a Doris via protocolo MySQL
mysql -h 127.0.0.1 -P 9030 -u root

# Verificar conteos
SELECT COUNT(*) FROM olist.customers;
SELECT COUNT(*) FROM olist.orders;
SELECT COUNT(*) FROM olist.order_items;
```

### Cancelar jobs

Si necesitas detener los jobs (por ejemplo, para reiniciar con cambios):

```bash
python cancel_flink_jobs.py
```

<details>
<summary>Script de cancelacion de jobs (Python)</summary>

```python
import sys
from typing import Any

import requests


def cancel_all_jobs(flink_base_url: str) -> int:
    normalized_base_url = flink_base_url.rstrip("/")
    overview_response = requests.get(
        f"{normalized_base_url}/jobs/overview",
        timeout=30,
    )
    overview_response.raise_for_status()

    jobs_payload: dict[str, Any] = overview_response.json()
    jobs = jobs_payload.get("jobs", [])

    cancellable_statuses = {
        "RUNNING", "RESTARTING", "CREATED", "DEPLOYING", "INITIALIZING",
    }
    job_identifier_list = [
        job["jid"] for job in jobs if job.get("state") in cancellable_statuses
    ]

    if not job_identifier_list:
        print("No cancellable jobs found.")
        return 0

    for job_identifier in job_identifier_list:
        cancel_response = requests.patch(
            f"{normalized_base_url}/jobs/{job_identifier}",
            params={"mode": "cancel"},
            timeout=30,
        )
        cancel_response.raise_for_status()
        print(f"Cancelled {job_identifier}")

    return 0


if __name__ == "__main__":
    flink_base_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8081"
    raise SystemExit(cancel_all_jobs(flink_base_url))
```

</details>

---

## 5. Apache Doris como OLAP

### Que es Apache Doris

Apache Doris es una base de datos analitica (OLAP) columnar de alto rendimiento. A diferencia de PostgreSQL (que es OLTP, optimizada para transacciones), Doris esta optimizada para:

| Caracteristica | PostgreSQL (OLTP) | Doris (OLAP) |
|----------------|-------------------|--------------|
| Optimizado para | Lecturas/escrituras de filas individuales | Escaneos masivos de columnas |
| Almacenamiento | Por filas | Por columnas |
| Queries tipicos | `SELECT * FROM orders WHERE id = 'abc'` | `SELECT SUM(price) FROM orders GROUP BY state` |
| Agregaciones | Lentas en tablas grandes | Muy rapidas (compresion columnar) |
| Concurrencia de escritura | Alta (muchos inserts/updates) | Moderada (cargas por lotes) |
| Uso tipico | Aplicaciones web, CRUD | Dashboards, reportes, BI |

### Modelo de tablas UNIQUE KEY en Doris

Doris soporta tres modelos de tabla: DUPLICATE, AGGREGATE y UNIQUE. Nosotros usamos **UNIQUE KEY**:

```sql
CREATE TABLE olist.customers (
    customer_id VARCHAR(255) NOT NULL,
    ...
) UNIQUE KEY (customer_id)                              -- Llave unica
  DISTRIBUTED BY HASH (customer_id) BUCKETS AUTO        -- Distribucion por hash
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

- **UNIQUE KEY:** Garantiza que solo existe una fila por llave. Si Flink envia un update para un `customer_id` que ya existe, Doris reemplaza la fila anterior. Esto es esencial para CDC, donde recibimos upserts.
- **DISTRIBUTED BY HASH:** Los datos se distribuyen entre "buckets" usando un hash de la llave. Esto permite paralelismo en queries.
- **BUCKETS AUTO:** Doris calcula automaticamente el numero de buckets.
- **replication_allocation = 1:** Una sola replica (ambiente de desarrollo). En produccion se usarian 3.

### Dos bases de datos en Doris

Nuestro pipeline crea dos bases:

```sql
CREATE DATABASE IF NOT EXISTS olist;       -- Capa staging (replica de la fuente)
CREATE DATABASE IF NOT EXISTS warehouse;   -- Capa analitica (esquema estrella)
```

```
              Doris
┌─────────────────────────────────────┐
│                                     │
│  olist (staging)    warehouse       │
│  ┌──────────────┐  ┌─────────────┐ │
│  │ customers    │  │ dim_customer│ │
│  │ orders       │  │ dim_product │ │
│  │ order_items  │  │ dim_seller  │ │
│  │ products     │  │ dim_time    │ │
│  │ sellers      │  │ ...         │ │
│  │ ...          │  │             │ │
│  │              │  │ fact_order  │ │
│  │              │  │   _item     │ │
│  └──────────────┘  └─────────────┘ │
│                                     │
│  Flink escribe ──▶  ETL interno    │
│  aqui               transforma     │
│                     staging →       │
│                     warehouse       │
└─────────────────────────────────────┘
```

---

## 6. Modelado dimensional (Kimball)

### Que es el esquema estrella

El esquema estrella es un patron de modelado de datos para data warehouses propuesto por Ralph Kimball. Organiza los datos en dos tipos de tablas:

- **Tabla de hechos (fact table):** Contiene las medidas numericas del negocio (precios, cantidades, montos). Cada fila representa un evento o transaccion.
- **Tablas de dimension:** Contienen los atributos descriptivos que contextualizan los hechos (quien, que, cuando, donde).

```
        dim_customer                dim_product
       ┌─────────────┐            ┌──────────────┐
       │customer_key  │            │product_key    │
       │customer_id   │            │product_id     │
       │city          │            │category_name  │
       │state         │            │weight_g       │
       └──────┬──────┘            │volume_cm3     │
              │                    └──────┬───────┘
              │                           │
         ┌────▼───────────────────────────▼────┐
         │         fact_order_item              │
         │                                     │
         │  order_id          (degenerada)      │
         │  order_item_id     (degenerada)      │
         │  customer_key ──── FK a dim_customer │
         │  product_key  ──── FK a dim_product  │
         │  seller_key   ──── FK a dim_seller   │
         │  status_key   ──── FK a dim_status   │
         │  date_key     ──── FK a dim_time     │
         │  item_price        MEDIDA            │
         │  freight_value     MEDIDA            │
         └─────────────────────────────────────┘
              │                           │
       ┌──────▼──────┐           ┌───────▼───────┐
       │ dim_seller   │           │dim_order_status│
       │seller_key    │           │status_key      │
       │seller_id     │           │order_status    │
       │city          │           └───────────────┘
       │state         │
       └─────────────┘
```

### Conceptos clave

**Grano (grain):** El nivel de detalle de cada fila en la tabla de hechos. En nuestro caso: **un articulo dentro de una orden**. Una orden con 3 productos genera 3 filas.

**Llave sustituta (surrogate key):** Una llave artificial auto-incremental (BIGINT) que reemplaza a la llave natural del sistema fuente. Se usa porque:

- Las llaves naturales pueden cambiar en la fuente.
- Son mas eficientes para joins (entero vs. string).
- Permiten manejar registros "desconocidos" (llave 0).

```sql
-- Ejemplo: customer_id es la llave natural, customer_key es la sustituta
customer_id VARCHAR(64) NOT NULL COMMENT 'Llave natural del origen',
customer_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
```

**Dimension degenerada:** Un atributo de dimension que vive directamente en la tabla de hechos, sin su propia tabla de dimension. En nuestro caso, `order_id` y `order_item_id` son degeneradas — no necesitan su propia tabla porque no tienen atributos adicionales utiles.

**Medidas (measures):** Los valores numericos que se agregan (SUM, AVG, COUNT). Nuestras medidas son `item_price` y `freight_value`.

**COALESCE con llave 0:** Cuando un hecho no tiene dimension correspondiente (ej. un producto que fue eliminado), usamos `COALESCE(dim_product.product_key, 0)` para asignar la llave 0 en lugar de NULL. Esto evita perder filas en JOINs.

### Nuestras dimensiones

| Dimension | Llave natural | Atributos | Tipo |
|-----------|--------------|-----------|------|
| dim_customer | customer_id | unique_id, zip_code, city, state | Regular |
| dim_seller | seller_id | zip_code, city, state | Regular |
| dim_product | product_id | category (EN/PT), peso, dimensiones, volumen, densidad | Regular (con campos calculados) |
| dim_geolocation | zip_code_prefix | city, state, lat, lng | Regular |
| dim_order_status | order_status | — | Mini-dimension (solo llave) |
| dim_payment_type | payment_type | — | Mini-dimension (solo llave) |
| dim_time | date_id (YYYYMMDD) | full_date, year, quarter, month, day, day_name, is_weekend | Dimension de tiempo |

---

## 7. Creacion de tablas en Doris

### Paso 1: Crear las bases de datos

```bash
python setup_doris.py
```

<details>
<summary>Script de creacion de tablas en Doris (Python)</summary>

```python
"""
Create all Doris tables: database setup, staging, dimensions, and facts.
Connects via MySQL protocol (port 9030) and executes the SQL statements.
"""

from pathlib import Path

import pymysql

DORIS_HOST = "localhost"
DORIS_PORT = 9030
DORIS_USER = "root"
DORIS_PASSWORD = ""

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WAREHOUSE_DIR = PROJECT_ROOT / "warehouse"

SQL_DIRS = [
    WAREHOUSE_DIR / "staging",
    WAREHOUSE_DIR / "dimensions",
    WAREHOUSE_DIR / "facts",
]


def main():
    connection = pymysql.connect(
        host=DORIS_HOST, port=DORIS_PORT,
        user=DORIS_USER, password=DORIS_PASSWORD,
    )

    try:
        cursor = connection.cursor()

        # Run database creation first
        setup_file = WAREHOUSE_DIR / "setup" / "create_database.sql"
        sql = setup_file.read_text(encoding="utf-8").strip()
        print(f"Running {setup_file.name} ...")
        cursor.execute(sql)
        print("  OK")

        # Run all table scripts from each directory
        for sql_dir in SQL_DIRS:
            for filepath in sorted(sql_dir.glob("*.sql")):
                sql = filepath.read_text(encoding="utf-8").strip()
                print(f"Running {sql_dir.name}/{filepath.name} ...")
                cursor.execute(sql)
                print("  OK")

        connection.commit()
        print("\nAll Doris tables created successfully.")
    except Exception as e:
        print(f"\nError: {e}")
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    main()
```

</details>

El script ejecuta todos los SQL en orden. Pero veamos que hace cada parte:

```sql
CREATE DATABASE IF NOT EXISTS olist;
CREATE DATABASE IF NOT EXISTS warehouse;

-- Workload group: limita concurrencia para evitar sobrecarga
CREATE WORKLOAD GROUP IF NOT EXISTS warehouse_load
PROPERTIES (
  "max_concurrency" = "32",
  "max_queue_size" = "200",
  "queue_timeout" = "10000"
);

GRANT USAGE_PRIV ON WORKLOAD GROUP 'warehouse_load' TO 'flink'@'%';
```

### Paso 2: Tablas staging (base `olist`)

Estas tablas son replicas de las tablas fuente en PostgreSQL. Flink escribe aqui via CDC.

```sql
CREATE TABLE IF NOT EXISTS olist.customers (
    customer_id VARCHAR(255) NOT NULL,
    customer_unique_id VARCHAR(255) NOT NULL,
    customer_zip_code_prefix VARCHAR(255) NOT NULL,
    customer_city VARCHAR(255) NOT NULL,
    customer_state VARCHAR(255) NOT NULL
) UNIQUE KEY (customer_id)
  DISTRIBUTED BY HASH (customer_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

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

Las demas 7 tablas staging:

<details>
<summary>Todas las tablas staging restantes</summary>

```sql
CREATE TABLE IF NOT EXISTS olist.order_items (
    order_id VARCHAR(255) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    seller_id VARCHAR(255) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DOUBLE NOT NULL,
    freight_value DOUBLE NOT NULL
) UNIQUE KEY (order_id, order_item_id)
  DISTRIBUTED BY HASH (order_id, order_item_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS olist.order_payments (
    order_id VARCHAR(255) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(255) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DOUBLE NOT NULL
) UNIQUE KEY (order_id, payment_sequential)
  DISTRIBUTED BY HASH (order_id, payment_sequential) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS olist.order_reviews (
    review_id VARCHAR(255) NOT NULL,
    order_id VARCHAR(255) NOT NULL,
    review_score INT NOT NULL,
    review_comment_title VARCHAR(255) NULL,
    review_comment_message VARCHAR(65533) NULL,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NULL
) UNIQUE KEY (review_id)
  DISTRIBUTED BY HASH (review_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS olist.products (
    product_id VARCHAR(255) NOT NULL,
    product_category_name VARCHAR(255) NULL,
    product_name_length INT NULL,
    product_description_length INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL
) UNIQUE KEY (product_id)
  DISTRIBUTED BY HASH (product_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS olist.sellers (
    seller_id VARCHAR(255) NOT NULL,
    seller_zip_code_prefix VARCHAR(255) NOT NULL,
    seller_city VARCHAR(255) NOT NULL,
    seller_state VARCHAR(255) NOT NULL
) UNIQUE KEY (seller_id)
  DISTRIBUTED BY HASH (seller_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS olist.geolocations (
    geolocation_zip_code_prefix VARCHAR(255) NOT NULL,
    geolocation_lat DECIMAL NOT NULL,
    geolocation_lng DECIMAL NOT NULL,
    geolocation_city VARCHAR(255) NOT NULL,
    geolocation_state VARCHAR(255) NOT NULL
) UNIQUE KEY (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng)
  DISTRIBUTED BY HASH (geolocation_lat, geolocation_lng) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS olist.product_category_name_translation (
    product_category_name VARCHAR(255) NOT NULL,
    product_category_name_english VARCHAR(255) NOT NULL
) UNIQUE KEY (product_category_name)
  DISTRIBUTED BY HASH (product_category_name) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

</details>

Se crean 9 tablas staging en total: customers, orders, order_items, order_payments, order_reviews, products, sellers, geolocations, product_category_name_translation.

### Paso 3: Tablas de dimension (base `warehouse`)

Cada dimension tiene una llave sustituta `AUTO_INCREMENT`:

```sql
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

-- Con campos calculados
CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_id VARCHAR(64) NOT NULL COMMENT 'Llave natural del origen',
    product_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
    product_english_category_name VARCHAR(256) NULL,
    product_category_name VARCHAR(256) NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,
    product_volume_cm3 INT NULL,            -- Calculado: largo * alto * ancho
    product_density_g_per_cm3 DOUBLE NULL   -- Calculado: peso / volumen
) UNIQUE KEY (product_id)
  DISTRIBUTED BY HASH (product_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS warehouse.dim_seller (
    seller_id VARCHAR(64) NOT NULL COMMENT 'Llave natural del origen',
    seller_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
    seller_zip_code_prefix VARCHAR(16) NOT NULL,
    seller_city VARCHAR(128) NOT NULL,
    seller_state VARCHAR(8) NOT NULL
) UNIQUE KEY (seller_id)
  DISTRIBUTED BY HASH (seller_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS warehouse.dim_geolocation (
    geolocation_zip_code_prefix VARCHAR(16) NOT NULL COMMENT 'Llave natural del origen',
    geolocation_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
    geolocation_city VARCHAR(128) NOT NULL,
    geolocation_state VARCHAR(8) NOT NULL,
    geolocation_lat DOUBLE NULL,
    geolocation_lng DOUBLE NULL
) UNIQUE KEY (geolocation_zip_code_prefix)
  DISTRIBUTED BY HASH (geolocation_zip_code_prefix) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

-- Mini-dimension
CREATE TABLE IF NOT EXISTS warehouse.dim_order_status (
    order_status VARCHAR(64) NOT NULL COMMENT 'Llave natural del origen',
    order_status_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta'
) UNIQUE KEY (order_status)
  DISTRIBUTED BY HASH (order_status) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

-- Mini-dimension
CREATE TABLE IF NOT EXISTS warehouse.dim_payment_type (
    payment_type VARCHAR(64) NOT NULL COMMENT 'Llave natural del origen',
    payment_type_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta'
) UNIQUE KEY (payment_type)
  DISTRIBUTED BY HASH (payment_type) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");

CREATE TABLE IF NOT EXISTS warehouse.dim_time (
    date_id INT NOT NULL COMMENT 'Llave natural, formato YYYYMMDD',
    time_key BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Llave sustituta',
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    day INT NOT NULL,
    day_of_week INT NOT NULL COMMENT 'Lunes=1 .. Domingo=7',
    day_name VARCHAR(16) NOT NULL COMMENT 'Monday .. Sunday',
    week_of_year_iso INT NOT NULL,
    is_weekend BOOLEAN NOT NULL
) UNIQUE KEY (date_id)
  DISTRIBUTED BY HASH (date_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

### Paso 4: Tabla de hechos (base `warehouse`)

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
    item_price DECIMAL(12, 2) NOT NULL,       -- Medida
    freight_value DECIMAL(12, 2) NOT NULL     -- Medida
) UNIQUE KEY (order_id, order_item_id)
  DISTRIBUTED BY HASH (order_id) BUCKETS AUTO
  PROPERTIES ("replication_allocation" = "tag.location.default: 1");
```

---

## 8. ETL: Poblar el esquema estrella

Una vez que Flink ha sincronizado los datos de PostgreSQL a las tablas staging de Doris, ejecutamos los scripts ETL para transformar esos datos en el esquema estrella.

```bash
python populate_warehouse.py
```

<details>
<summary>Script de ETL del warehouse (Python)</summary>

```python
from pathlib import Path

from sqlalchemy import create_engine

database_url = "mysql+pymysql://root:@localhost:9030/warehouse?charset=utf8mb4"

engine = create_engine(
    database_url,
    pool_pre_ping=True,
)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ETL_DIR = PROJECT_ROOT / "warehouse" / "etl"

sql_file_paths = [
    ETL_DIR / "insert_dim_customer.sql",
    ETL_DIR / "insert_dim_seller.sql",
    ETL_DIR / "insert_dim_geolocation.sql",
    ETL_DIR / "insert_dim_payment_type.sql",
    ETL_DIR / "insert_dim_order_status.sql",
    ETL_DIR / "insert_dim_product.sql",
    ETL_DIR / "insert_fact_table.sql",
]


def split_sql_statements(sql_text: str) -> list[str]:
    return [statement.strip() for statement in sql_text.split(";") if statement.strip()]


with engine.begin() as connection:
    for sql_file_path in sql_file_paths:
        sql_content = sql_file_path.read_text(encoding="utf-8")
        sql_statements = split_sql_statements(sql_content)
        for sql_statement in sql_statements:
            connection.exec_driver_sql(sql_statement)
```

</details>

### Orden de ejecucion

Es importante respetar el orden: **primero las dimensiones, luego los hechos**, porque la tabla de hechos referencia las llaves sustitutas de las dimensiones.

```
1. dim_customer       ─┐
2. dim_seller          │
3. dim_geolocation     ├── Dimensiones (sin dependencias entre si)
4. dim_payment_type    │
5. dim_order_status    │
6. dim_product        ─┘
7. fact_order_item    ─── Hechos (depende de todas las dimensiones)
```

### Inserts de dimensiones

Cada insert extrae valores distintos desde staging, filtrando NULLs:

```sql
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

```sql
INSERT INTO warehouse.dim_seller (
    seller_id, seller_zip_code_prefix, seller_city, seller_state
)
SELECT DISTINCT
    sellers.seller_id,
    sellers.seller_zip_code_prefix,
    sellers.seller_city,
    sellers.seller_state
FROM olist.sellers AS sellers
WHERE sellers.seller_zip_code_prefix IS NOT NULL
  AND sellers.seller_city IS NOT NULL
  AND sellers.seller_state IS NOT NULL;
```

```sql
INSERT INTO warehouse.dim_geolocation (
    geolocation_zip_code_prefix, geolocation_city,
    geolocation_state, geolocation_lat, geolocation_lng
)
SELECT DISTINCT
    geolocations.geolocation_zip_code_prefix,
    geolocations.geolocation_city,
    geolocations.geolocation_state,
    geolocations.geolocation_lat,
    geolocations.geolocation_lng
FROM olist.geolocations AS geolocations
WHERE geolocations.geolocation_zip_code_prefix IS NOT NULL
  AND geolocations.geolocation_city IS NOT NULL
  AND geolocations.geolocation_state IS NOT NULL;
```

Las mini-dimensiones son aun mas simples:

```sql
INSERT INTO warehouse.dim_order_status (order_status)
SELECT DISTINCT orders.order_status
FROM olist.orders AS orders
WHERE orders.order_status IS NOT NULL;

INSERT INTO warehouse.dim_payment_type (payment_type)
SELECT DISTINCT order_payments.payment_type
FROM olist.order_payments AS order_payments
WHERE order_payments.payment_type IS NOT NULL;
```

`dim_product` es la mas interesante porque calcula campos derivados:

```sql
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
    -- Volumen = largo * alto * ancho
    products.product_length_cm * products.product_height_cm * products.product_width_cm,
    -- Densidad = peso / volumen
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

### Insert de la tabla de hechos

Este es el query mas complejo del ETL. Hace JOINs con las tablas staging y las dimensiones para resolver las llaves sustitutas:

```sql
INSERT INTO warehouse.fact_order_item (
    order_id, order_item_id,
    product_key, customer_key, seller_key, order_status_key,
    order_date_key,
    item_price, freight_value
)
SELECT
    order_items.order_id,
    order_items.order_item_id,

    -- Resolver llaves sustitutas via JOINs
    -- COALESCE(..., 0) asigna llave 0 si no hay match (registro desconocido)
    COALESCE(dim_product.product_key, 0),
    COALESCE(dim_customer.customer_key, 0),
    COALESCE(dim_seller.seller_key, 0),
    COALESCE(dim_order_status.order_status_key, 0),

    -- Convertir timestamp a date_id entero (YYYYMMDD)
    CAST(DATE_FORMAT(orders.order_purchase_timestamp, '%%Y%%m%%d') AS INT),

    -- Medidas
    order_items.price,
    order_items.freight_value

FROM olist.order_items AS order_items

-- JOIN con la tabla de ordenes (para obtener customer_id y status)
JOIN olist.orders AS orders
    ON order_items.order_id = orders.order_id

-- JOINs con las dimensiones para resolver llaves sustitutas
JOIN warehouse.dim_customer AS dim_customer
    ON orders.customer_id = dim_customer.customer_id
LEFT JOIN warehouse.dim_product AS dim_product
    ON order_items.product_id = dim_product.product_id
LEFT JOIN warehouse.dim_seller AS dim_seller
    ON order_items.seller_id = dim_seller.seller_id
LEFT JOIN warehouse.dim_order_status AS dim_order_status
    ON orders.order_status = dim_order_status.order_status;
```

Observaciones sobre los JOINs:
- **`JOIN dim_customer`** es INNER porque toda orden debe tener un cliente.
- **`LEFT JOIN dim_product/dim_seller/dim_order_status`** son LEFT para no perder hechos si una dimension no tiene match. En ese caso, COALESCE asigna la llave 0.
- **`DATE_FORMAT(..., '%%Y%%m%%d')`** convierte el timestamp a un entero YYYYMMDD que es la llave de `dim_time`.

### Verificar el resultado

```sql
-- Conectar a Doris
mysql -h 127.0.0.1 -P 9030 -u root

-- Conteos por tabla
SELECT 'dim_customer' AS tabla, COUNT(*) AS filas FROM warehouse.dim_customer
UNION ALL SELECT 'dim_seller', COUNT(*) FROM warehouse.dim_seller
UNION ALL SELECT 'dim_product', COUNT(*) FROM warehouse.dim_product
UNION ALL SELECT 'dim_order_status', COUNT(*) FROM warehouse.dim_order_status
UNION ALL SELECT 'dim_payment_type', COUNT(*) FROM warehouse.dim_payment_type
UNION ALL SELECT 'dim_time', COUNT(*) FROM warehouse.dim_time
UNION ALL SELECT 'fact_order_item', COUNT(*) FROM warehouse.fact_order_item;

-- Query desnormalizado: unir hechos con todas las dimensiones
SELECT
    f.order_id,
    f.order_item_id,
    f.item_price,
    f.freight_value,
    c.customer_city,
    c.customer_state,
    s.seller_city,
    s.seller_state,
    p.product_english_category_name,
    p.product_volume_cm3,
    os.order_status,
    t.full_date AS order_date,
    t.year AS order_year,
    t.quarter AS order_quarter,
    t.day_name AS order_day_name,
    t.is_weekend AS order_is_weekend
FROM warehouse.fact_order_item AS f
JOIN warehouse.dim_customer AS c ON f.customer_key = c.customer_key
JOIN warehouse.dim_seller AS s ON f.seller_key = s.seller_key
JOIN warehouse.dim_product AS p ON f.product_key = p.product_key
JOIN warehouse.dim_order_status AS os ON f.order_status_key = os.order_status_key
LEFT JOIN warehouse.dim_time AS t ON f.order_date_key = t.date_id
LIMIT 10;
```

---

## 9. Visualizacion con Apache Superset

### Que es Apache Superset

Apache Superset es una plataforma open-source de BI (Business Intelligence) y visualizacion de datos. Permite crear dashboards interactivos conectandose directamente a bases de datos SQL.

### Agregar Superset al docker-compose

Superset no esta incluido en la configuracion base de Docker Compose. Para agregarlo, anade este servicio:

```yaml
  superset:
    image: apache/superset:latest
    container_name: superset
    restart: unless-stopped
    ports:
      - "8088:8088"
    depends_on:
      - doris
```

Luego levantalo y crea el usuario admin:

```bash
docker compose up -d superset

# Crear usuario administrador
docker compose exec superset superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@example.com \
  --password admin

# Inicializar la base de datos interna de Superset
docker compose exec superset superset db upgrade

# Inicializar Superset
docker compose exec superset superset init
```

### Instalar el dialecto de Doris

Superset se conecta a bases de datos a traves de SQLAlchemy. Para que pueda hablar con Doris, necesitamos instalar el dialecto:

```bash
docker compose exec superset bash -lc "pip install sqlalchemy-doris"
```

Despues de instalar, reinicia el contenedor para que tome efecto:

```bash
docker compose restart superset
```

### Conectar Superset a Doris

1. Abrir Superset en el navegador: `http://localhost:8088`
2. Iniciar sesion con las credenciales del admin (`admin` / `admin`)
3. Ir a **Settings** (engranaje arriba a la derecha) → **Database Connections** → **+ Database**
4. Seleccionar **Other** como tipo de base de datos
5. En el campo **SQLAlchemy URI**, escribir:

```
doris://root:@doris:9030/warehouse
```

> **Nota:** Usamos `doris` (nombre del contenedor) como host porque Superset esta en la misma red Docker. Si Superset estuviera fuera de Docker, seria `localhost`.

6. Click en **Test Connection** para verificar
7. Click en **Connect**

### Crear un Dataset

Un "dataset" en Superset es una tabla o query que sirve como fuente de datos para graficas.

**Opcion A — Tabla directa:**

1. Ir a **Datasets** → **+ Dataset**
2. Seleccionar la base de datos que acabas de crear
3. Schema: `warehouse`
4. Tabla: `fact_order_item`
5. Click en **Create Dataset and Create Chart**

**Opcion B — Query SQL personalizado (recomendado):**

Es mejor crear un dataset basado en el query desnormalizado que une la fact table con todas las dimensiones, asi tienes todos los atributos disponibles para las graficas:

1. Ir a **SQL Lab** → **SQL Editor**
2. Seleccionar la base de datos de Doris y ejecutar el query:

```sql
SELECT
    f.order_id,
    f.order_item_id,
    f.item_price,
    f.freight_value,
    f.item_price + f.freight_value AS total_revenue,
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

3. Click en **Save** → **Save Dataset**
4. Nombre: `fact_order_item_full`

### Crear el primer dashboard

Una vez que tienes el dataset, puedes crear graficas. Estas son las recomendadas para un primer dashboard:

#### 1. KPI Cards (Tarjetas de metricas)

Crear 4 tarjetas con las metricas principales:

| Metrica | Formula en Superset | Formato |
|---------|-------------------|---------|
| Ingreso Total | `SUM(item_price) + SUM(freight_value)` | Moneda |
| Total Ordenes | `COUNT_DISTINCT(order_id)` | Numero |
| Valor Promedio por Orden | `(SUM(item_price) + SUM(freight_value)) / COUNT_DISTINCT(order_id)` | Moneda |
| Ratio de Flete | `SUM(freight_value) / (SUM(item_price) + SUM(freight_value))` | Porcentaje |

#### 2. Line Chart — Ingreso por mes

- **Eje X (Dimension):** `order_date`, granularidad mensual
- **Metrica:** `SUM(item_price)`
- **Titulo:** "Ingreso mensual"

#### 3. Bar Chart — Ingreso por categoria

- **Eje X (Dimension):** `product_english_category_name`
- **Metrica:** `SUM(item_price)`
- **Ordenar por:** Metrica descendente
- **Limite de filas:** 15
- **Orientacion:** Horizontal
- **Titulo:** "Top 15 categorias por ingreso"

#### 4. Bar Chart — Ingreso por estado

- **Eje X (Dimension):** `customer_state`
- **Metrica:** `SUM(item_price)`
- **Ordenar por:** Metrica descendente
- **Titulo:** "Ingreso por estado"

#### 5. Stacked Bar — Status de ordenes por mes

- **Eje X (Dimension):** `order_date`, granularidad mensual
- **Metrica:** `COUNT_DISTINCT(order_id)`
- **Dimension de color (Group by):** `order_status`
- **Titulo:** "Status de ordenes por mes"

#### 6. Scatter Plot — Flete vs. precio

- **Eje X:** `item_price`
- **Eje Y:** `freight_value`
- **Titulo:** "Flete vs. precio del articulo"

### Filtros del dashboard

Agrega estos filtros interactivos para exploracion:

- **Rango de fecha:** Filtra por `order_date`
- **Categoria:** Filtra por `product_english_category_name`
- **Estado del cliente:** Filtra por `customer_state`
- **Status de orden:** Filtra por `order_status`

### Metricas de referencia

Definir estas metricas una vez en Superset para reutilizarlas en todas las graficas:

```
Ingreso bruto        = SUM(item_price)
Ingreso por flete    = SUM(freight_value)
Ingreso total        = SUM(item_price + freight_value)
Total de ordenes     = COUNT(DISTINCT order_id)
Total de articulos   = COUNT(*)
Valor promedio orden = SUM(item_price + freight_value) / COUNT(DISTINCT order_id)
Precio promedio      = SUM(item_price) / COUNT(*)
Ratio de flete       = SUM(freight_value) / SUM(item_price + freight_value)
```

### Preguntas de negocio que puedes responder

Con el dashboard completo puedes explorar:

- Cuanto estamos vendiendo y como evoluciona el ingreso en el tiempo
- Que categorias y productos generan mas ingreso
- Que vendedores y estados son los mas rentables
- Cual es el valor promedio de una orden
- Que proporcion del ingreso es flete
- Que categorias tienen el mayor costo de flete relativo
- Como se distribuyen los status de las ordenes (entregadas, canceladas, etc.)
- Que periodos tienen picos o caidas inusuales
- Que productos son los mas pesados, voluminosos o ineficientes de enviar
- Que patrones existen por dia de la semana o fin de semana

---

## Resumen del flujo completo

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  1. PostgreSQL tiene los datos cargados (presentacion anterior)         │
│     └── 10 tablas: customers, orders, order_items, products, ...        │
│                                                                         │
│  2. Configuramos CDC en PostgreSQL                                      │
│     └── REPLICA IDENTITY + publicacion olist_publication                │
│                                                                         │
│  3. Flink lee cambios del WAL y los escribe en Doris (streaming)        │
│     └── 10 jobs continuos, exactly-once, checkpointing cada 10s        │
│                                                                         │
│  4. Doris recibe datos en tablas staging (base olist)                   │
│     └── Replicas exactas de las tablas fuente                           │
│                                                                         │
│  5. ETL transforma staging → esquema estrella (base warehouse)          │
│     └── 7 dimensiones + 1 tabla de hechos                               │
│                                                                         │
│  6. Superset se conecta al warehouse y crea dashboards                  │
│     └── Graficas, KPIs, filtros interactivos                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
