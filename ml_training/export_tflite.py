import tensorflow as tf


def convert_to_tflite(keras_path, tflite_path):
    model = tf.keras.models.load_model(keras_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    converter._experimental_lower_tensor_list_ops = False
    tflite_model = converter.convert()

    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    print(f'Saved {tflite_path}')


if __name__ == '__main__':
    convert_to_tflite('red_ball_model.keras', 'red_ball_model.tflite')
    convert_to_tflite('blue_ball_model.keras', 'blue_ball_model.tflite')
