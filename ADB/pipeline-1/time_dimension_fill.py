from datetime import date, timedelta
from typing import List

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from base import Base
from warehouse.dimensions.time_dimension import TimeDimension

database_url = "postgresql+psycopg2://postgres_user:postgres_pass@localhost:5435/olist"
engine = create_engine(database_url, pool_pre_ping=True)
Base.metadata.create_all(engine)


def build_time_dimension_rows(
    start_date_inclusive: date,
    end_date_inclusive: date,
) -> List[TimeDimension]:
    rows: List[TimeDimension] = []

    current_date = start_date_inclusive
    while current_date <= end_date_inclusive:
        iso_year, iso_week, iso_weekday = current_date.isocalendar()

        rows.append(
            TimeDimension(
                date_id=(current_date.year * 10000)
                + (current_date.month * 100)
                + current_date.day,
                full_date=current_date,
                year=iso_year,
                # Quarter 1 → Jan-Mar Quarter 2 → Apr-Jun Quarter 3 → Jul-Sep Quarter 4 → Oct-Dec
                quarter=((current_date.month - 1) // 3) + 1,
                month=current_date.month,
                day=current_date.day,
                day_of_week=iso_weekday,
                day_name=current_date.strftime("%A"),
                week_of_year_iso=iso_week,
                is_weekend=iso_weekday > 5,
            )
        )

        current_date += timedelta(days=1)

    return rows


rows = build_time_dimension_rows(
    start_date_inclusive=date(year=2015, month=1, day=1),
    end_date_inclusive=date(year=2019, month=12, day=31),
)
with Session(engine) as session:
    session.add_all(rows)
    session.commit()
