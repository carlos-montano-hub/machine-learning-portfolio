from keras import Input, Model
from keras.layers import Dense, Concatenate, Add

# Feature sizes
n_energy_features = 5  # Change as needed
n_mfcc_features = 13  # Change as needed

# Inputs
energy_input = Input(shape=(n_energy_features,), name="energy_input")
mfcc_input = Input(shape=(n_mfcc_features,), name="mfcc_input")

# Energy branch
x_energy = energy_input
for i in range(4):
    x_energy = Dense(64, activation="relu", name=f"energy_dense_{i+1}")(x_energy)

# MFCC branch
x_mfcc = mfcc_input
for i in range(4):
    x_mfcc = Dense(64, activation="relu", name=f"mfcc_dense_{i+1}")(x_mfcc)

# Central branch (energy + mfcc concatenated)
combined = Concatenate(name="concat_energy_mfcc")([energy_input, mfcc_input])
x_central = combined
for i in range(4):
    x_central = Dense(64, activation="relu", name=f"central_dense_{i+1}")(x_central)

# Auxiliary outputs (add central branch)
energy_add = Add(name="energy_add")([x_energy, x_central])
mfcc_add = Add(name="mfcc_add")([x_mfcc, x_central])

# Each output is a single neuron with sigmoid activation
energy_output = Dense(1, activation="sigmoid", name="energy_output")(energy_add)
mfcc_output = Dense(1, activation="sigmoid", name="mfcc_output")(mfcc_add)
real_output = Dense(1, activation="sigmoid", name="real_output")(x_central)

# Build model
model = Model(
    inputs=[energy_input, mfcc_input],
    outputs=[energy_output, mfcc_output, real_output],
    name="Beehivemulti-branch",
)
model.save("beehive_multi_branch.keras")
model.summary()
