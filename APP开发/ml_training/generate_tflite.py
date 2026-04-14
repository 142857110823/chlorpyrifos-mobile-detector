#!/usr/bin/env python3
"""
TFLite Model Generator for Pesticide Detection App
===================================================
Generates TensorFlow Lite models for pesticide classification and concentration regression.

Requirements: pip install tensorflow numpy scikit-learn
Usage: python generate_tflite.py
"""

import os
import numpy as np

try:
    import tensorflow as tf
    from tensorflow import keras
    TF_AVAILABLE = True
    print(f"TensorFlow version: {tf.__version__}")
except ImportError:
    TF_AVAILABLE = False
    print("WARNING: TensorFlow not installed. Run: pip install tensorflow")

def generate_synthetic_training_data(n_samples=5000):
    np.random.seed(42)
    n_wavelengths = 256
    X, y_class, y_concentration = [], [], []
    
    for i in range(n_samples):
        cls = np.random.randint(0, 5)
        wavelengths = np.linspace(200, 1100, n_wavelengths)
        base = 0.3 + 0.4 * np.exp(-((wavelengths - 550) ** 2) / (2 * 150 ** 2))
        
        if cls == 0:
            spectrum = base + np.random.normal(0, 0.02, n_wavelengths)
            concentration = 0.0
        elif cls == 1:
            peak1 = 0.15 * np.exp(-((wavelengths - 280) ** 2) / (2 * 20 ** 2))
            peak2 = 0.10 * np.exp(-((wavelengths - 450) ** 2) / (2 * 30 ** 2))
            concentration = np.random.uniform(0.01, 0.5)
            spectrum = base - concentration * (peak1 + peak2) + np.random.normal(0, 0.02, n_wavelengths)
        elif cls == 2:
            peak = 0.20 * np.exp(-((wavelengths - 320) ** 2) / (2 * 25 ** 2))
            concentration = np.random.uniform(0.01, 0.4)
            spectrum = base - concentration * peak + np.random.normal(0, 0.02, n_wavelengths)
        elif cls == 3:
            peak1 = 0.12 * np.exp(-((wavelengths - 250) ** 2) / (2 * 15 ** 2))
            peak2 = 0.08 * np.exp(-((wavelengths - 380) ** 2) / (2 * 20 ** 2))
            concentration = np.random.uniform(0.01, 0.3)
            spectrum = base - concentration * (peak1 + peak2) + np.random.normal(0, 0.02, n_wavelengths)
        else:
            peak1 = 0.18 * np.exp(-((wavelengths - 270) ** 2) / (2 * 18 ** 2))
            peak2 = 0.12 * np.exp(-((wavelengths - 420) ** 2) / (2 * 25 ** 2))
            concentration = np.random.uniform(0.01, 0.35)
            spectrum = base - concentration * (peak1 + peak2) + np.random.normal(0, 0.02, n_wavelengths)
        
        spectrum = np.clip(spectrum, 0, 1)
        X.append(spectrum)
        y_class.append(cls)
        y_concentration.append(concentration)
    
    return np.array(X, dtype=np.float32), np.array(y_class), np.array(y_concentration, dtype=np.float32)


def build_classifier_model(input_shape=(256,), num_classes=5):
    model = keras.Sequential([
        keras.layers.Input(shape=input_shape),
        keras.layers.Dense(128, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.3),
        keras.layers.Dense(64, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(32, activation="relu"),
        keras.layers.Dense(num_classes, activation="softmax")
    ])
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    return model

def build_regressor_model(input_shape=(256,)):
    model = keras.Sequential([
        keras.layers.Input(shape=input_shape),
        keras.layers.Dense(128, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.3),
        keras.layers.Dense(64, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(32, activation="relu"),
        keras.layers.Dense(1, activation="linear")
    ])
    model.compile(optimizer="adam", loss="mse", metrics=["mae"])
    return model

def convert_to_tflite(model, output_path, quantize=True):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if quantize:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    with open(output_path, "wb") as f:
        f.write(tflite_model)
    print(f"Saved TFLite model to: {output_path} ({len(tflite_model) / 1024:.2f} KB)")
    return tflite_model


def main():
    if not TF_AVAILABLE:
        print("ERROR: TensorFlow is required. Install with: pip install tensorflow")
        return
    
    output_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
    os.makedirs(output_dir, exist_ok=True)
    
    print("=" * 60)
    print("Pesticide Detection TFLite Model Generator")
    print("=" * 60)
    
    print("\n[1/5] Generating synthetic training data...")
    X, y_class, y_concentration = generate_synthetic_training_data(n_samples=5000)
    print(f"Generated {len(X)} samples with shape {X.shape}")
    
    from sklearn.model_selection import train_test_split
    X_train, X_test, y_class_train, y_class_test = train_test_split(X, y_class, test_size=0.2, random_state=42)
    _, _, y_conc_train, y_conc_test = train_test_split(X, y_concentration, test_size=0.2, random_state=42)
    
    print("\n[2/5] Training classification model...")
    classifier = build_classifier_model()
    classifier.fit(X_train, y_class_train, validation_data=(X_test, y_class_test), epochs=50, batch_size=32, verbose=1)
    
    print("\n[3/5] Evaluating classification model...")
    loss, accuracy = classifier.evaluate(X_test, y_class_test)
    print(f"Test accuracy: {accuracy:.4f}")
    
    print("\n[4/5] Training regression model...")
    mask_train = y_class_train > 0
    mask_test = y_class_test > 0
    regressor = build_regressor_model()
    regressor.fit(X_train[mask_train], y_conc_train[mask_train], validation_data=(X_test[mask_test], y_conc_test[mask_test]), epochs=50, batch_size=32, verbose=1)
    
    print("\n[5/5] Converting to TFLite format...")
    classifier_path = os.path.join(output_dir, "pesticide_classifier.tflite")
    regressor_path = os.path.join(output_dir, "concentration_regressor.tflite")
    convert_to_tflite(classifier, classifier_path)
    convert_to_tflite(regressor, regressor_path)
    
    print("\n" + "=" * 60)
    print("Model generation complete!")
    print("=" * 60)

if __name__ == "__main__":
    main()

