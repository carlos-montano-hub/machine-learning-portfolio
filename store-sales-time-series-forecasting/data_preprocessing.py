import pandas as pd
from calendar import timegm
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import time
import numpy as np
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
data_dir = os.path.join(script_dir, "data")

data_path = os.path.join(data_dir, "data.csv")
train = pd.read_csv(data_path)

print(train.head())
print(train.describe())

X = train.drop("sales", axis=1)
Y = train["sales"]


X["date"] = [
    timegm(time.strptime(date, "%Y-%m-%d")) for date in X["date"]
]  # Convert date to timestamp

X_train, X_test, y_train, y_test = train_test_split(
    X, Y, test_size=0.2, random_state=42
)  # Split data into training and testing sets

label_encoder = LabelEncoder()  # Encode categorical variables
X_train["family"] = label_encoder.fit_transform(X_train["family"])
X_test["family"] = label_encoder.transform(X_test["family"])

scaler = StandardScaler()
X_train = scaler.fit_transform(X_train)
X_test = scaler.fit_transform(X_test)

y_train = y_train.astype(np.float32)
y_test = y_test.astype(np.float32)

np.save(f"{data_dir}/X_train.npy", X_train)
np.save(f"{data_dir}/X_test.npy", X_test)
np.save(f"{data_dir}/y_train.npy", y_train)
np.save(f"{data_dir}/y_test.npy", y_test)
