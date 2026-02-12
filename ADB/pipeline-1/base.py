from typing import Optional
from sqlalchemy import Column, Float, ForeignKey, Integer, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, foreign
from datetime import datetime


class Base(DeclarativeBase):
    pass
