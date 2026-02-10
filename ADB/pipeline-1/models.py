from typing import Optional
from sqlalchemy import Column, Float, ForeignKey, Integer, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, foreign
from datetime import datetime


class Base(DeclarativeBase):
    pass


class Geolocation(Base):
    __tablename__ = "geolocations"

    geolocation_zip_code_prefix: Mapped[str]
    geolocation_lat: Mapped[float] = mapped_column(primary_key=True)
    geolocation_lng: Mapped[float] = mapped_column(primary_key=True)
    geolocation_city: Mapped[str]
    geolocation_state: Mapped[str]


class Customer(Base):
    __tablename__ = "customers"

    customer_id: Mapped[str] = mapped_column(primary_key=True)
    customer_unique_id: Mapped[str] = mapped_column(index=True)
    customer_zip_code_prefix: Mapped[str]
    customer_city: Mapped[str]
    customer_state: Mapped[str]

    orders: Mapped[list["Order"]] = relationship(back_populates="customer")


class Seller(Base):
    __tablename__ = "sellers"

    seller_id: Mapped[str] = mapped_column(primary_key=True)
    seller_zip_code_prefix: Mapped[str]
    seller_city: Mapped[str]
    seller_state: Mapped[str]

    order_items: Mapped[list["OrderItem"]] = relationship(back_populates="seller")


class ProductCategoryTranslation(Base):
    __tablename__ = "product_category_name_translation"

    product_category_name: Mapped[str] = mapped_column(primary_key=True)
    product_category_name_english: Mapped[str]

    products: Mapped[list["Product"]] = relationship(
        back_populates="category_translation"
    )


class Product(Base):
    __tablename__ = "products"

    product_id: Mapped[str] = mapped_column(primary_key=True)
    product_category_name: Mapped[Optional[str]] = mapped_column(
        ForeignKey("product_category_name_translation.product_category_name")
    )
    product_name_length: Mapped[Optional[int]]
    product_description_length: Mapped[Optional[int]]
    product_photos_qty: Mapped[Optional[int]]
    product_weight_g: Mapped[Optional[int]]
    product_length_cm: Mapped[Optional[int]]
    product_height_cm: Mapped[Optional[int]]
    product_width_cm: Mapped[Optional[int]]

    category_translation: Mapped[Optional["ProductCategoryTranslation"]] = relationship(
        back_populates="products"
    )
    order_items: Mapped[list["OrderItem"]] = relationship(back_populates="product")


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
    payments: Mapped[list["OrderPayment"]] = relationship(back_populates="order")
    review: Mapped[Optional["OrderReview"]] = relationship(
        back_populates="order", uselist=False
    )


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

    order: Mapped["Order"] = relationship(back_populates="items")
    product: Mapped["Product"] = relationship(back_populates="order_items")
    seller: Mapped["Seller"] = relationship(back_populates="order_items")


class OrderPayment(Base):
    __tablename__ = "order_payments"

    order_id: Mapped[str] = mapped_column(
        ForeignKey("orders.order_id"), primary_key=True
    )
    payment_sequential: Mapped[int] = mapped_column(primary_key=True)
    payment_type: Mapped[str]
    payment_installments: Mapped[int]
    payment_value: Mapped[float]

    order: Mapped["Order"] = relationship(back_populates="payments")


class OrderReview(Base):
    __tablename__ = "order_reviews"

    review_id: Mapped[str] = mapped_column(primary_key=True)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.order_id"))
    review_score: Mapped[int]
    review_comment_title: Mapped[Optional[str]]
    review_comment_message: Mapped[Optional[str]]
    review_creation_date: Mapped[datetime]
    review_answer_timestamp: Mapped[Optional[datetime]]

    order: Mapped["Order"] = relationship(back_populates="review")
