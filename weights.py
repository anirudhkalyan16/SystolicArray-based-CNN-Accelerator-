import os
import time
import gzip
import shutil
import struct
import numpy as np
import tensorflow as tf
import kagglehub

# SETUP

SEED = 42
np.random.seed(SEED)
tf.random.set_seed(SEED)

cwd = os.getcwd()
print("Current working directory:", cwd)

# DOWNLOAD / LOCATE MNIST

print("\nDownloading / locating MNIST...")

kaggle_path = kagglehub.dataset_download("hojjatk/mnist-dataset")
local_dataset_dir = os.path.join(cwd, "mnist_dataset")

if not os.path.exists(local_dataset_dir):
    print("Copying MNIST into current working directory...")
    shutil.copytree(kaggle_path, local_dataset_dir)

print("Dataset directory:", local_dataset_dir)


def find_file(keyword):
    for root, _, files in os.walk(local_dataset_dir):
        for filename in files:
            if keyword in filename:
                return os.path.join(root, filename)
    return None


train_images_file = find_file("train-images")
train_labels_file = find_file("train-labels")
test_images_file = find_file("t10k-images")
test_labels_file = find_file("t10k-labels")

if None in [
    train_images_file,
    train_labels_file,
    test_images_file,
    test_labels_file
]:
    raise FileNotFoundError("Could not find all required MNIST files.")

# LOAD IDX FILES

def open_mnist_file(filename):
    if filename.endswith(".gz"):
        return gzip.open(filename, "rb")
    return open(filename, "rb")


def load_idx_images(filename):
    with open_mnist_file(filename) as file:
        magic = struct.unpack(">I", file.read(4))[0]
        number_images = struct.unpack(">I", file.read(4))[0]
        rows = struct.unpack(">I", file.read(4))[0]
        cols = struct.unpack(">I", file.read(4))[0]

        if magic != 2051:
            raise ValueError("Invalid MNIST image file.")

        data = np.frombuffer(file.read(), dtype=np.uint8)

    return data.reshape(number_images, rows, cols)


def load_idx_labels(filename):
    with open_mnist_file(filename) as file:
        magic = struct.unpack(">I", file.read(4))[0]
        number_labels = struct.unpack(">I", file.read(4))[0]

        if magic != 2049:
            raise ValueError("Invalid MNIST label file.")

        labels = np.frombuffer(file.read(), dtype=np.uint8)

    if len(labels) != number_labels:
        raise ValueError("MNIST label count mismatch.")

    return labels


print("\nLoading MNIST...")

x_train = load_idx_images(train_images_file)
y_train_original = load_idx_labels(train_labels_file)

x_test = load_idx_images(test_images_file)
y_test_original = load_idx_labels(test_labels_file)

print("Training:", x_train.shape, y_train_original.shape)
print("Testing :", x_test.shape, y_test_original.shape)

# CREATE 0 / 1 / NEITHER CLASSES

y_train = np.where(
    y_train_original == 0,
    0,
    np.where(y_train_original == 1, 1, 2)
)

y_test = np.where(
    y_test_original == 0,
    0,
    np.where(y_test_original == 1, 1, 2)
)

print("\nOriginal 3-class training distribution:")
print("Zero   :", np.sum(y_train == 0))
print("One    :", np.sum(y_train == 1))
print("Neither:", np.sum(y_train == 2))

# BALANCE TRAINING SET

idx_0 = np.where(y_train == 0)[0]
idx_1 = np.where(y_train == 1)[0]
idx_2 = np.where(y_train == 2)[0]

samples_per_class = min(len(idx_0), len(idx_1), len(idx_2))

idx_0 = np.random.choice(idx_0, samples_per_class, replace=False)
idx_1 = np.random.choice(idx_1, samples_per_class, replace=False)
idx_2 = np.random.choice(idx_2, samples_per_class, replace=False)

training_indices = np.concatenate([idx_0, idx_1, idx_2])
np.random.shuffle(training_indices)

x_train = x_train[training_indices]
y_train = y_train[training_indices]

print("\nBalanced training set:")
print("Total  :", len(x_train))
print("Zero   :", np.sum(y_train == 0))
print("One    :", np.sum(y_train == 1))
print("Neither:", np.sum(y_train == 2))

print("\nTest set:")
print("Total  :", len(x_test))
print("Zero   :", np.sum(y_test == 0))
print("One    :", np.sum(y_test == 1))
print("Neither:", np.sum(y_test == 2))

# RESIZE 28x28 -> 8x8

def resize_images(images):
    images = tf.convert_to_tensor(images, dtype=tf.float32)
    images = tf.expand_dims(images, axis=-1)

    resized = tf.image.resize(
        images,
        [8, 8],
        method="bilinear"
    )
    resized = tf.round(resized)
    resized = tf.clip_by_value(resized, 0, 255)
    resized = tf.cast(resized, tf.int32)
    resized = tf.squeeze(resized, axis=-1)
    return resized.numpy()


print("\nResizing images...")
x_train_8 = resize_images(x_train)
x_test_8 = resize_images(x_test)
print("Training:", x_train_8.shape)
print("Testing :", x_test_8.shape)

# HARDWARE PREPROCESSING
# Sobel-X -> ReLU -> 2x2 MaxPool -> 9 values

sobel_x = np.array([
    [-1, 0, 1],
    [-2, 0, 2],
    [-1, 0, 1]
], dtype=np.int32)

def sobel_convolution(image):
    output = np.zeros((6, 6), dtype=np.int32)

    for row in range(6):
        for col in range(6):
            region = image[row:row + 3, col:col + 3]
            output[row, col] = np.sum(region * sobel_x)

    return output

def relu(image):
    return np.maximum(image, 0)

def max_pool(image):
    output = np.zeros((3, 3), dtype=np.int32)

    for row in range(3):
        for col in range(3):
            region = image[
                row * 2:row * 2 + 2,
                col * 2:col * 2 + 2
            ]

            output[row, col] = np.max(region)

    return output

def extract_features(images):
    features = np.zeros((len(images), 9), dtype=np.float32)

    for i, image in enumerate(images):
        conv = sobel_convolution(image)
        activated = relu(conv)
        pooled = max_pool(activated)

        features[i] = pooled.flatten()

        if (i + 1) % 5000 == 0 or i + 1 == len(images):
            print("Processed", i + 1, "/", len(images))

    return features

print("\nExtracting training features...")
start = time.perf_counter()
x_train_features_raw = extract_features(x_train_8)
print(
    "Training feature extraction time:",
    time.perf_counter() - start,
    "seconds"
)
print("\nExtracting test features...")
x_test_features_raw = extract_features(x_test_8)
print("Training features:", x_train_features_raw.shape)
print("Testing features :", x_test_features_raw.shape)

# NORMALIZATION

FEATURE_SCALE = 1020.0
x_train_features = x_train_features_raw / FEATURE_SCALE
x_test_features = x_test_features_raw / FEATURE_SCALE
print("\nFeature range:")
print("Min:", np.min(x_train_features))
print("Max:", np.max(x_train_features))

# FC MODEL: 9 -> 8 -> 3

model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(9,)),
    tf.keras.layers.Dense(
        8,
        activation="relu",
        name="fc1"
    ),
    tf.keras.layers.Dense(
        3,
        activation=None,
        name="fc2"
    )
])

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
    loss=tf.keras.losses.SparseCategoricalCrossentropy(
        from_logits=True
    ),
    metrics=["accuracy"]
)

print("\nModel:")
model.summary()

# TRAIN

print("\nTraining...")
training_start = time.perf_counter()
model.fit(
    x_train_features,
    y_train,
    epochs=50,
    batch_size=64,
    validation_split=0.1,
    shuffle=True,
    verbose=1
)
training_time = time.perf_counter() - training_start
print("\nTraining time:", training_time, "seconds")

# FLOAT TEST

test_loss, test_accuracy = model.evaluate(
    x_test_features,
    y_test,
    verbose=0
)

# Warm-up
_ = model.predict(x_test_features[:100], verbose=0)

inference_start = time.perf_counter()

logits = model.predict(
    x_test_features,
    batch_size=1,
    verbose=0
)

python_inference_time = time.perf_counter() - inference_start
predictions = np.argmax(logits, axis=1)
python_latency = python_inference_time / len(x_test_features)
python_throughput = len(x_test_features) / python_inference_time
print("\n========================================")
print("FLOAT PYTHON RESULTS")
print("========================================")

print("Test loss       :", test_loss)
print("Test accuracy   :", test_accuracy * 100, "%")
print("Latency         :", python_latency * 1000, "ms/image")
print("Throughput      :", python_throughput, "images/second")

confusion = tf.math.confusion_matrix(
    y_test,
    predictions,
    num_classes=3
)
print("\nFloat confusion matrix:")
print(confusion.numpy())

for class_number in range(3):
    indices = np.where(y_test == class_number)[0]

    accuracy = np.mean(
        predictions[indices] == y_test[indices]
    )

    print(
        "Class",
        class_number,
        "accuracy:",
        accuracy * 100,
        "%"
    )


# GET TRAINED FC PARAMETERS

fc1_weights, fc1_bias = model.get_layer("fc1").get_weights()
fc2_weights, fc2_bias = model.get_layer("fc2").get_weights()
print("\nParameter shapes:")
print("FC1 weights:", fc1_weights.shape)
print("FC1 bias   :", fc1_bias.shape)
print("FC2 weights:", fc2_weights.shape)
print("FC2 bias   :", fc2_bias.shape)

# QUANTIZATION

WEIGHT_SCALE = 64
fc1_weights_q = np.round(
    fc1_weights * WEIGHT_SCALE
).astype(np.int32)

fc2_weights_q = np.round(
    fc2_weights * WEIGHT_SCALE
).astype(np.int32)

fc1_weights_q = np.clip(fc1_weights_q, -128, 127)
fc2_weights_q = np.clip(fc2_weights_q, -128, 127)

fc1_bias_q = np.round(
    fc1_bias * FEATURE_SCALE * WEIGHT_SCALE
).astype(np.int64)

fc2_bias_q = np.round(
    fc2_bias
    * FEATURE_SCALE
    * WEIGHT_SCALE
    * WEIGHT_SCALE
).astype(np.int64)

INT32_MIN = -(2 ** 31)
INT32_MAX = (2 ** 31) - 1

fc1_bias_q = np.clip(
    fc1_bias_q,
    INT32_MIN,
    INT32_MAX
).astype(np.int32)

fc2_bias_q = np.clip(
    fc2_bias_q,
    INT32_MIN,
    INT32_MAX
).astype(np.int32)

print("\nQuantized ranges:")
print(
    "FC1 weights:",
    np.min(fc1_weights_q),
    "to",
    np.max(fc1_weights_q)
)

print(
    "FC2 weights:",
    np.min(fc2_weights_q),
    "to",
    np.max(fc2_weights_q)
)

print(
    "FC1 bias:",
    np.min(fc1_bias_q),
    "to",
    np.max(fc1_bias_q)
)

print(
    "FC2 bias:",
    np.min(fc2_bias_q),
    "to",
    np.max(fc2_bias_q)
)

# INTEGER / RTL-STYLE INFERENCE

def integer_inference(features):
    predictions_int = []
    all_fc2_outputs = []

    for sample in features:

        # FC1: 9 -> 8 + ReLU
        fc1_out = np.zeros(8, dtype=np.int64)

        for neuron in range(8):
            accumulator = int(fc1_bias_q[neuron])

            for i in range(9):
                accumulator += (
                    int(sample[i])
                    * int(fc1_weights_q[i, neuron])
                )
            if accumulator < 0:
                accumulator = 0
            fc1_out[neuron] = accumulator

        # FC2: 8 -> 3
        fc2_out = np.zeros(3, dtype=np.int64)

        for neuron in range(3):
            accumulator = int(fc2_bias_q[neuron])

            for i in range(8):
                accumulator += (
                    int(fc1_out[i])
                    * int(fc2_weights_q[i, neuron])
                )

            fc2_out[neuron] = accumulator

        predictions_int.append(np.argmax(fc2_out))
        all_fc2_outputs.append(fc2_out)

    return (
        np.array(predictions_int),
        np.array(all_fc2_outputs)
    )

print("\nRunning integer RTL-style inference...")

integer_predictions, integer_fc2_outputs = integer_inference(
    x_test_features_raw.astype(np.int32)
)

integer_accuracy = np.mean(
    integer_predictions == y_test
)

agreement = np.mean(
    integer_predictions == predictions
)

integer_confusion = tf.math.confusion_matrix(
    y_test,
    integer_predictions,
    num_classes=3
)

print("INTEGER / RTL-STYLE RESULTS")
print("Float accuracy   :", test_accuracy * 100, "%")
print("Integer accuracy :", integer_accuracy * 100, "%")
print("Float/INT agree  :", agreement * 100, "%")
print("\nInteger confusion matrix:")
print(integer_confusion.numpy())
for class_number in range(3):
    indices = np.where(y_test == class_number)[0]

    accuracy = np.mean(
        integer_predictions[indices] == y_test[indices]
    )
    print(
        "Class",
        class_number,
        "accuracy:",
        accuracy * 100,
        "%"
    )
def integer_inference(features):
    predictions_int = []

    all_fc2_outputs = []

    for sample in features:

        # FC1

        fc1_out = np.zeros(8, dtype=np.int64)

        for neuron in range(8):

            accumulator = int(fc1_bias_q[neuron])

            for i in range(9):

                accumulator += (

                    int(sample[i])

                    *

                    int(fc1_weights_q[i, neuron])

                )

            if accumulator < 0:

                accumulator = 0

            fc1_out[neuron] = accumulator

        # FC2

        fc2_out = np.zeros(3, dtype=np.int64)

        for neuron in range(3):

            accumulator = int(fc2_bias_q[neuron])

            for i in range(8):

                accumulator += (

                    int(fc1_out[i])

                    *

                    int(fc2_weights_q[i, neuron])

                )

            fc2_out[neuron] = accumulator

        predictions_int.append(np.argmax(fc2_out))

        all_fc2_outputs.append(fc2_out)

    return (

        np.array(predictions_int),

        np.array(all_fc2_outputs)

    )
print("RTL TEST VECTOR - IMAGE 0")
sample = x_test_features_raw[0].astype(np.int32)
print("Actual class:")
print(y_test[0])
print("\n9 pooled inputs:")
print(sample)
fc1_expected = []

for neuron in range(8):

    acc = int(fc1_bias_q[neuron])

    for i in range(9):
        acc += (
            int(sample[i])
            *
            int(fc1_weights_q[i, neuron])
        )

    if acc < 0:
        acc = 0

    fc1_expected.append(acc)

print("\nExpected FC1 outputs:")
print(fc1_expected)
print("\nExpected FC2 outputs:")
print(integer_fc2_outputs[0])
print("\nExpected prediction:")
print(integer_predictions[0])
print("INTEGER / RTL-STYLE INFERENCE")

integer_predictions, integer_fc2_outputs = integer_inference(

    x_test_features_raw.astype(np.int32)

)

integer_accuracy = np.mean(

    integer_predictions == y_test

)

agreement = np.mean(

    integer_predictions == predictions

)

print("Float accuracy   :", test_accuracy * 100, "%")
print("Integer accuracy :", integer_accuracy * 100, "%")
print("Float/INT agree  :", agreement * 100, "%")
integer_confusion = tf.math.confusion_matrix(

    y_test,

    integer_predictions,

    num_classes=3

)
print("\nInteger confusion matrix:")
print(integer_confusion.numpy())

# HEX EXPORT

def to_hex8(value):
    return format(int(value) & 0xFF, "02X")

def to_hex32(value):
    return format(int(value) & 0xFFFFFFFF, "08X")

fc1_weights_path = os.path.join(cwd, "fc1_weights.hex")
fc1_bias_path = os.path.join(cwd, "fc1_bias.hex")
fc2_weights_path = os.path.join(cwd, "fc2_weights.hex")
fc2_bias_path = os.path.join(cwd, "fc2_bias.hex")

# RTL ordering:
# FC1 weights[(neuron * 9) + input]

with open(fc1_weights_path, "w") as file:
    for neuron in range(8):
        for input_index in range(9):
            file.write(
                to_hex8(
                    fc1_weights_q[input_index, neuron]
                ) + "\n"
            )


with open(fc1_bias_path, "w") as file:
    for neuron in range(8):
        file.write(
            to_hex32(fc1_bias_q[neuron]) + "\n"
        )

# RTL ordering:
# FC2 weights[(neuron * 8) + input]

with open(fc2_weights_path, "w") as file:
    for neuron in range(3):
        for input_index in range(8):
            file.write(
                to_hex8(
                    fc2_weights_q[input_index, neuron]
                ) + "\n"
            )

with open(fc2_bias_path, "w") as file:
    for neuron in range(3):
        file.write(
            to_hex32(fc2_bias_q[neuron]) + "\n"
        )

def count_lines(filename):
    with open(filename, "r") as file:
        return sum(1 for line in file if line.strip())

assert count_lines(fc1_weights_path) == 72
assert count_lines(fc1_bias_path) == 8
assert count_lines(fc2_weights_path) == 24
assert count_lines(fc2_bias_path) == 3

print("\nHEX files generated successfully:")
print("fc1_weights.hex: 72 values")
print("fc1_bias.hex   : 8 values")
print("fc2_weights.hex: 24 values")
print("fc2_bias.hex   : 3 values")

# SAVE DATA FOR RTL COMPARISON

np.save(
    os.path.join(cwd, "x_test_8.npy"),
    x_test_8
)

np.save(
    os.path.join(cwd, "x_test_features_raw.npy"),
    x_test_features_raw.astype(np.int32)
)

np.save(
    os.path.join(cwd, "y_test.npy"),
    y_test
)

np.save(
    os.path.join(cwd, "python_predictions.npy"),
    predictions
)

np.save(
    os.path.join(cwd, "integer_predictions.npy"),
    integer_predictions
)

np.save(
    os.path.join(cwd, "integer_fc2_outputs.npy"),
    integer_fc2_outputs
)

# FINAL SUMMARY

print("FINAL SUMMARY")
print("Training images:", len(x_train))
print("Test images:", len(x_test))
print("Float accuracy:", test_accuracy * 100, "%")
print("Integer accuracy:", integer_accuracy * 100, "%")
print("Float/INT agreement:", agreement * 100, "%")
print("Python FC latency:", python_latency * 1000, "ms/image")
print("Python FC throughput:", python_throughput, "images/second")
print("\nGenerated:")
print("fc1_weights.hex")
print("fc1_bias.hex")
print("fc2_weights.hex")
print("fc2_bias.hex")
print("\nDone.")