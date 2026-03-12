from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from base import Base


class GeolocationDimension(Base):
    __tablename__ = "dim_geolocation"

    geolocation_key: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )

    geolocation_zip_code_prefix: Mapped[str] = mapped_column(String(16), nullable=False)
    geolocation_city: Mapped[str] = mapped_column(String(128), nullable=False)
    geolocation_state: Mapped[str] = mapped_column(String(8), nullable=False)
    geolocation_lat: Mapped[float]
    geolocation_lng: Mapped[float]
