from sqlalchemy import create_engine
import pandas as pd
from sqlalchemy.orm import Session
from base import Base
from source_db_models import (
    Customer,
    Geolocation,
    Order,
    OrderItem,
    OrderPayment,
    OrderReview,
    Product,
    ProductCategoryTranslation,
    Seller,
)
from reader import read_dataframes

database_url = "postgresql+psycopg2://postgres_user:postgres_pass@localhost:5435/olist"
engine = create_engine(database_url, pool_pre_ping=True)
Base.metadata.drop_all(engine)
Base.metadata.create_all(engine)

(
    customers_dataframe,
    geolocation_dataframe,
    order_items_dataframe,
    order_payments_dataframe,
    order_reviews_dataframe,
    orders_dataframe,
    products_dataframe,
    sellers_dataframe,
    product_category_name_translation_dataframe,
) = read_dataframes()

with Session(engine) as session:
    print("Uploading Geolocation")
    session.bulk_save_objects(
        [
            Geolocation(
                geolocation_zip_code_prefix=row["geolocation_zip_code_prefix"],
                geolocation_lat=float(row["geolocation_lat"]),
                geolocation_lng=float(row["geolocation_lng"]),
                geolocation_city=row["geolocation_city"],
                geolocation_state=row["geolocation_state"],
            )
            for _, row in geolocation_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading ProductCategoryTr")
    session.bulk_save_objects(
        [
            ProductCategoryTranslation(
                product_category_name=row["product_category_name"],
                product_category_name_english=row["product_category_name_english"],
            )
            for _, row in product_category_name_translation_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading Customer")
    session.bulk_save_objects(
        [
            Customer(
                customer_id=row["customer_id"],
                customer_unique_id=row["customer_unique_id"],
                customer_zip_code_prefix=row["customer_zip_code_prefix"],
                customer_city=row["customer_city"],
                customer_state=row["customer_state"],
            )
            for _, row in customers_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading Seller")
    session.bulk_save_objects(
        [
            Seller(
                seller_id=row["seller_id"],
                seller_zip_code_prefix=row["seller_zip_code_prefix"],
                seller_city=row["seller_city"],
                seller_state=row["seller_state"],
            )
            for _, row in sellers_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading Product")
    session.bulk_save_objects(
        [
            Product(
                product_id=row["product_id"],
                product_category_name=(row["product_category_name"] or None),
                product_name_length=(
                    None
                    if pd.isna(row.get("product_name_length"))
                    else int(row["product_name_length"])
                ),
                product_description_length=(
                    None
                    if pd.isna(row.get("product_description_length"))
                    else int(row["product_description_length"])
                ),
                product_photos_qty=(
                    None
                    if pd.isna(row.get("product_photos_qty"))
                    else int(row["product_photos_qty"])
                ),
                product_weight_g=(
                    None
                    if pd.isna(row.get("product_weight_g"))
                    else int(row["product_weight_g"])
                ),
                product_length_cm=(
                    None
                    if pd.isna(row.get("product_length_cm"))
                    else int(row["product_length_cm"])
                ),
                product_height_cm=(
                    None
                    if pd.isna(row.get("product_height_cm"))
                    else int(row["product_height_cm"])
                ),
                product_width_cm=(
                    None
                    if pd.isna(row.get("product_width_cm"))
                    else int(row["product_width_cm"])
                ),
            )
            for _, row in products_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading Order")
    session.bulk_save_objects(
        [
            Order(
                order_id=row["order_id"],
                customer_id=row["customer_id"],
                order_status=row["order_status"],
                order_purchase_timestamp=(
                    None
                    if pd.isna(row["order_purchase_timestamp"])
                    else row["order_purchase_timestamp"].to_pydatetime()
                ),
                order_approved_at=(
                    None
                    if pd.isna(row["order_approved_at"])
                    else row["order_approved_at"].to_pydatetime()
                ),
                order_delivered_carrier_date=(
                    None
                    if pd.isna(row["order_delivered_carrier_date"])
                    else row["order_delivered_carrier_date"].to_pydatetime()
                ),
                order_delivered_customer_date=(
                    None
                    if pd.isna(row["order_delivered_customer_date"])
                    else row["order_delivered_customer_date"].to_pydatetime()
                ),
                order_estimated_delivery_date=(
                    None
                    if pd.isna(row["order_estimated_delivery_date"])
                    else row["order_estimated_delivery_date"].to_pydatetime()
                ),
            )
            for _, row in orders_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading OrderItem")
    session.bulk_save_objects(
        [
            OrderItem(
                order_id=row["order_id"],
                order_item_id=int(row["order_item_id"]),
                product_id=row["product_id"],
                seller_id=row["seller_id"],
                shipping_limit_date=(
                    None
                    if pd.isna(row["shipping_limit_date"])
                    else row["shipping_limit_date"].to_pydatetime()
                ),
                price=float(row["price"]),
                freight_value=float(row["freight_value"]),
            )
            for _, row in order_items_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading OrderPayment")
    session.bulk_save_objects(
        [
            OrderPayment(
                order_id=row["order_id"],
                payment_sequential=int(row["payment_sequential"]),
                payment_type=row["payment_type"],
                payment_installments=int(row["payment_installments"]),
                payment_value=float(row["payment_value"]),
            )
            for _, row in order_payments_dataframe.iterrows()
        ]
    )
    session.commit()

    print("Uploading OrderReview")
    session.bulk_save_objects(
        [
            OrderReview(
                review_id=row["review_id"],
                order_id=row["order_id"],
                review_score=int(row["review_score"]),
                review_comment_title=(row["review_comment_title"] or None),
                review_comment_message=(row["review_comment_message"] or None),
                review_creation_date=(
                    None
                    if pd.isna(row["review_creation_date"])
                    else row["review_creation_date"].to_pydatetime()
                ),
                review_answer_timestamp=(
                    None
                    if pd.isna(row["review_answer_timestamp"])
                    else row["review_answer_timestamp"].to_pydatetime()
                ),
            )
            for _, row in order_reviews_dataframe.iterrows()
        ]
    )
    session.commit()
