import os
import numpy as np
import time
import tensorflow as tf
from tensorflow import keras

# Load data
script_dir = os.path.dirname(os.path.abspath(__file__))
data_dir = os.path.join(script_dir, "data")
X_train = np.load(f"{data_dir}/X_train.npy")
y_train = np.load(f"{data_dir}/y_train.npy")
start_time = time.time()


# Model builder function for Talos
def build_model(x_train, y_train, x_val, y_val, params):
    model = keras.Sequential()
    model.add(keras.layers.InputLayer(input_shape=(X_train.shape[1],)))

    # Add layers with independently tuned neurons and activations
    for i in range(params["num_layers"]):
        model.add(
            keras.layers.Dense(
                params[f"units_layer_{i+1}"],
                activation=params[f"activation_layer_{i+1}"],
            )
        )

    model.add(keras.layers.Dense(1))  # Output layer for regression

    # Select optimizer dynamically
    optimizer = {
        "adam": keras.optimizers.Adam(learning_rate=params["learning_rate"]),
        "sgd": keras.optimizers.SGD(learning_rate=params["learning_rate"]),
        "rmsprop": keras.optimizers.RMSprop(learning_rate=params["learning_rate"]),
    }[params["optimizer"]]

    # Compile the model with dynamic optimizer and loss
    model.compile(optimizer=optimizer, loss=params["loss"], metrics=["mae", "r2_score"])

    history = model.fit(
        x_train,
        y_train,
        validation_data=(x_val, y_val),
        epochs=params["epochs"],
        batch_size=params["batch_size"],
        verbose=0,
    )

    return history, model


# Define the parameter grid
param_grid = {
    "num_layers": [2],
    "units_layer_1": [64, 128],
    "units_layer_2": [64, 128],
    "units_layer_3": [64, 128],
    "activation_layer_1": ["relu", "sigmoid"],
    "activation_layer_2": ["relu", "sigmoid"],
    "activation_layer_3": ["relu", "sigmoid"],
    "batch_size": [8],
    "epochs": [10],
    "learning_rate": [0.001, 0.01, 0.0001],
    "optimizer": ["adam"],
    "loss": [
        # "mse",
        "mae",
    ],
}

# Run Talos scan
scan = talos.Scan(
    x=X_train,
    y=y_train,
    params=param_grid,
    model=build_model,
    experiment_name="regression_talos",
    round_limit=10,
)

# Get the best model
best_model = talos.Evaluate(scan).best_model(metric="val_mae", asc=True)
end_time = time.time()

# Save the best model
best_model.save(f"{data_dir}/best_talos_model.keras")

print("Tuning complete. Best model saved.")

total_time = end_time - start_time
avg_time_per_iter = total_time / 1080
# Save the time results to a text file
time_log_path = os.path.join(script_dir, "talos_runtime_log.txt")
with open(time_log_path, "w") as f:
    f.write(f"Total time: {total_time / 3600:.2f} hours\n")
    f.write(f"Average time per iteration: {avg_time_per_iter:.2f} seconds\n")
print(f"Runtime log saved to {time_log_path}")
