from datetime import date, timedelta
from typing import List

from dimensions.time_dimension import TimeDimension


def build_time_dimension_rows(
    start_date: date,
    end_date_inclusive: date,
) -> List[TimeDimension]:
    rows: List[TimeDimension] = []

    current_date = start_date
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
