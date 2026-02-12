from typing import Optional
from sqlalchemy import ForeignKey, Integer, Date, String, Float, Computed
from sqlalchemy.orm import Mapped, mapped_column, relationship
import datetime

from base import Base


class ProductDimension(Base):
    __tablename__ = "dim_product"
    product_id: Mapped[str] = mapped_column(primary_key=True)
    product_english_category_name: Mapped[str]
    product_category_name: Mapped[str]
    product_weight_g: Mapped[int]
    product_length_cm: Mapped[int]
    product_height_cm: Mapped[int]
    product_width_cm: Mapped[int]
    product_volume_cm3: Mapped[Optional[int]] = mapped_column(
        Integer,
        Computed(
            "product_length_cm * product_height_cm * product_width_cm",
            persisted=True,
        ),
    )
    product_density_g_per_cm3: Mapped[Optional[float]]
