# Beehive Audio Anomaly Detection – Multi-Branch Neural Network

## Overview

This project implements a multi-branch neural network in Keras for detecting anomalies in beehive audio data. The architecture leverages two distinct sets of features:

- **Energy-related features** (e.g., entropy, overall energy)
- **MFCCs** (Mel-Frequency Cepstral Coefficients, 13 banks)

By combining these features in both independent and shared processing branches, the model aims to robustly identify anomalies in beehive activity, supporting research in precision apiculture and beehive health monitoring.

The premise for this architecture is that both MFCC and energy-related features are, individually, capable of anomaly detection.

## Why Auxiliary Outputs?

Including auxiliary outputs allows gradients from their losses to flow not only through their respective branches but also back into the central branch. This means that the central branch is influenced by the learning signals from both the energy and MFCC auxiliary tasks, not just the main output. As a result:

- **Shared Representation Learning:** The central branch learns representations that are useful for both the main and auxiliary tasks, improving its ability to generalize.
- **Regularization:** Backpropagation from auxiliary outputs acts as a form of regularization, reducing overfitting by encouraging the central branch to capture features relevant to all outputs.
- **Improved Convergence:** The additional gradient signals can help the model converge faster and avoid local minima associated with optimizing only the main output.

This design ensures that the central branch is not isolated but is actively shaped by all available supervision, leading to a more robust anomaly detector.

## Architecture

**Inputs:**

- `energy_input`: Vector of energy-related features (e.g., 5 features)
- `mfcc_input`: Vector of MFCC features (e.g., 13 features)

**Branches:**

- **Energy Branch:** 4 Dense layers, processes only energy features
- **MFCC Branch:** 4 Dense layers, processes only MFCC features
- **Central Branch:** 4 Dense layers, processes concatenated energy + MFCC features

**Outputs:**

- `energy_output`: Predicts anomaly likelihood from energy features + central branch (auxiliary output, sigmoid activation)
- `mfcc_output`: Predicts anomaly likelihood from MFCC features + central branch (auxiliary output, sigmoid activation)
- `real_output`: Predicts anomaly likelihood from central branch only (main output, sigmoid activation)

**All outputs are single-neuron (sigmoid) activations.**

Diagram:

```
energy_input → [Energy Branch] ──┐
                                 ├─[Add]→ energy_output
central (energy+mfcc)→[Central]─┘
mfcc_input → [MFCC Branch] ─────┐
                                 ├─[Add]→ mfcc_output
central (energy+mfcc)→[Central]─┘

central (energy+mfcc)→[Central] → real_output
```

---

## Training

- **Losses:**
  The model uses three binary cross-entropy losses (one for each output), with customizable loss weights.
- **Regularization:**
  Auxiliary outputs encourage each feature set to learn anomaly-relevant representations, improving main task generalization.

---

## Usage

### Requirements

- Python 3.7+
- TensorFlow 2.x / Keras

### Installation

```bash
pip install tensorflow
```

### Model Definition

See [`model.py`](model.py) for the full architecture.

## Visualization

You can visualize the model architecture using [Netron](https://netron.app/):

```python
model.save('beehive_multi-branch.h5')
```

- Open `beehive_multi-branch.h5` in Netron to inspect the model structure.

---

## Notes

- **Feature Assumptions:**
  This model assumes both MFCC and energy-related features are, individually, capable of anomaly detection.
- **Auxiliary Outputs:**
  Help regularize training and encourage learning from both feature modalities.

---

## License

[MIT License](LICENSE)

---

## Acknowledgments

- MFCC computation: [librosa](https://librosa.org/)
- Inspiration: [Netron](https://netron.app/), Keras documentation
