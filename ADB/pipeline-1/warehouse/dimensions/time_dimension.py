import datetime

from sqlalchemy import Date, Integer
from sqlalchemy.orm import Mapped, mapped_column

from base import Base


class TimeDimension(Base):
    __tablename__ = "dim_time"

    date_id: Mapped[int] = mapped_column(Integer, primary_key=True)  # YYYYMMDD
    full_date: Mapped[datetime.date] = mapped_column(
        Date, nullable=False, unique=True, index=True
    )
    year: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    quarter: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    month: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    day: Mapped[int]
    day_of_week: Mapped[int]  # Monday:1..Sunday:7
    day_name: Mapped[str]  # Monday..Sunday
    week_of_year_iso: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    is_weekend: Mapped[bool]  # true false
