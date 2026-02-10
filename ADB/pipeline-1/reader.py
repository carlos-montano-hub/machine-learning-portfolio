import pandas as pd


def read_dataframes():
    customers_dataframe = pd.read_csv("raw_data/olist_customers_dataset.csv", dtype=str)
    geolocation_dataframe = pd.read_csv(
        "raw_data/olist_geolocation_dataset.csv", dtype=str
    )
    order_items_dataframe = pd.read_csv(
        "raw_data/olist_order_items_dataset.csv", dtype=str
    )
    order_payments_dataframe = pd.read_csv(
        "raw_data/olist_order_payments_dataset.csv", dtype=str
    )
    order_reviews_dataframe = pd.read_csv(
        "raw_data/olist_order_reviews_dataset.csv", dtype=str
    )
    orders_dataframe = pd.read_csv("raw_data/olist_orders_dataset.csv", dtype=str)
    products_dataframe = pd.read_csv("raw_data/olist_products_dataset.csv", dtype=str)
    sellers_dataframe = pd.read_csv("raw_data/olist_sellers_dataset.csv", dtype=str)
    product_category_name_translation_dataframe = pd.read_csv(
        "raw_data/product_category_name_translation.csv", dtype=str
    )

    geolocation_dataframe["geolocation_lat"] = pd.to_numeric(
        geolocation_dataframe["geolocation_lat"], errors="raise"
    ).astype("float64")
    geolocation_dataframe["geolocation_lng"] = pd.to_numeric(
        geolocation_dataframe["geolocation_lng"], errors="raise"
    ).astype("float64")
    geolocation_dataframe = geolocation_dataframe.drop_duplicates(
        subset=["geolocation_lat", "geolocation_lng"]
    )
    order_items_dataframe["shipping_limit_date"] = pd.to_datetime(
        order_items_dataframe["shipping_limit_date"], errors="coerce"
    )
    order_items_dataframe["order_item_id"] = pd.to_numeric(
        order_items_dataframe["order_item_id"], errors="raise"
    ).astype("int64")
    order_items_dataframe["price"] = pd.to_numeric(
        order_items_dataframe["price"], errors="raise"
    ).astype("float64")
    order_items_dataframe["freight_value"] = pd.to_numeric(
        order_items_dataframe["freight_value"], errors="raise"
    ).astype("float64")

    order_payments_dataframe["payment_sequential"] = pd.to_numeric(
        order_payments_dataframe["payment_sequential"], errors="raise"
    ).astype("int64")
    order_payments_dataframe["payment_installments"] = pd.to_numeric(
        order_payments_dataframe["payment_installments"], errors="raise"
    ).astype("int64")
    order_payments_dataframe["payment_value"] = pd.to_numeric(
        order_payments_dataframe["payment_value"], errors="raise"
    )

    order_reviews_dataframe["review_creation_date"] = pd.to_datetime(
        order_reviews_dataframe["review_creation_date"], errors="coerce"
    )
    order_reviews_dataframe["review_answer_timestamp"] = pd.to_datetime(
        order_reviews_dataframe["review_answer_timestamp"], errors="coerce"
    )
    order_reviews_dataframe["review_score"] = pd.to_numeric(
        order_reviews_dataframe["review_score"], errors="raise"
    ).astype("int64")

    orders_dataframe["order_purchase_timestamp"] = pd.to_datetime(
        orders_dataframe["order_purchase_timestamp"], errors="coerce"
    )
    orders_dataframe["order_approved_at"] = pd.to_datetime(
        orders_dataframe["order_approved_at"], errors="coerce"
    )
    orders_dataframe["order_delivered_carrier_date"] = pd.to_datetime(
        orders_dataframe["order_delivered_carrier_date"], errors="coerce"
    )
    orders_dataframe["order_delivered_customer_date"] = pd.to_datetime(
        orders_dataframe["order_delivered_customer_date"], errors="coerce"
    )
    orders_dataframe["order_estimated_delivery_date"] = pd.to_datetime(
        orders_dataframe["order_estimated_delivery_date"], errors="coerce"
    )

    for column_name in [
        "product_name_length",
        "product_description_length",
        "product_photos_qty",
        "product_weight_g",
        "product_length_cm",
        "product_height_cm",
        "product_width_cm",
    ]:
        products_dataframe[column_name] = pd.to_numeric(
            products_dataframe[column_name], errors="coerce"
        )
    products_dataframe = products_dataframe[
        products_dataframe["product_category_name"].notna()
        & (products_dataframe["product_category_name"] != "")
    ]
    valid_categories = set(
        product_category_name_translation_dataframe["product_category_name"]
    )
    products_dataframe = products_dataframe[
        products_dataframe["product_category_name"].isin(valid_categories)
    ]
    valid_product_ids = set(products_dataframe["product_id"])

    order_items_dataframe = order_items_dataframe[
        order_items_dataframe["product_id"].isin(valid_product_ids)
    ]

    order_reviews_dataframe = order_reviews_dataframe.drop_duplicates(
        subset=["review_id"],
        keep="first",
    )
    return (
        customers_dataframe,
        geolocation_dataframe,
        order_items_dataframe,
        order_payments_dataframe,
        order_reviews_dataframe,
        orders_dataframe,
        products_dataframe,
        sellers_dataframe,
        product_category_name_translation_dataframe,
    )
