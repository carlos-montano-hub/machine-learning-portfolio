from typing import Optional
from sqlalchemy import  ForeignKey,Integer,Date,String
from sqlalchemy.orm import  Mapped, mapped_column, relationship
import datetime 

from base import Base

class DimTime(Base):
    __tablename__ = "dim_time"
    __table_args__ = {"schema": "dw"}

    date_id: Mapped[int] = mapped_column(Integer, primary_key=True)  
    # Example: 20260211 (YYYYMMDD surrogate key)

    full_date: Mapped[datetime.date] = mapped_column(Date, nullable=False, unique=True)  
    # Example: 2026-02-11

    year: Mapped[int]  
    # Example: 2026

    quarter: Mapped[int]  
    # Example: 1  (for January)

    month: Mapped[int]  
    # Example: 2  (February)

    day: Mapped[int]  
    # Example: 11

    day_of_week_iso: Mapped[int]  
    # Example: 3  (ISO: 1=Monday ... 7=Sunday)

    day_of_year: Mapped[int]  
    # Example: 42  (42nd day of the year)

    week_of_year_iso: Mapped[int]  
    # Example: 7  (ISO week number)

    month_name: Mapped[str]  
    # Example: "February"

    day_name: Mapped[str]  
    # Example: "Wednesday"

    year_quarter_label: Mapped[str]  
    # Example: "2026 Q1"

    year_month_label: Mapped[str]  
    # Example: "2026-02"

    is_weekend: Mapped[bool]  
    # Example: True (Saturday), False (Wednesday)