from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from base import Base


class SellerDimension(Base):
    __tablename__ = "dim_seller"

    seller_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    seller_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)

    seller_zip_code_prefix: Mapped[str] = mapped_column(String(16), nullable=False)
    seller_city: Mapped[str] = mapped_column(String(128), nullable=False)
    seller_state: Mapped[str] = mapped_column(String(8), nullable=False)
