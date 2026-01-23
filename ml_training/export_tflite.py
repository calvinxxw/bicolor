import os
os.environ["KERAS_BACKEND"] = "tensorflow"
import tensorflow as tf
from tensorflow import keras

def convert_models():
    print("Converting high-precision models to TFLite...")
    
    # Convert Red Ensemble Model
    red_model = keras.models.load_model('red_ball_model.keras', safe_mode=False)
    converter = tf.lite.TFLiteConverter.from_keras_model(red_model)
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    converter._experimental_lower_tensor_list_ops = False
    
    tflite_red = converter.convert()
    with open('red_ball_model.tflite', 'wb') as f:
        f.write(tflite_red)
    print("Red Ensemble TFLite: Success.")

    # Convert Blue Expert Model
    if os.path.exists('blue_ball_model.keras'):
        blue_model = keras.models.load_model('blue_ball_model.keras', safe_mode=False)
        converter_blue = tf.lite.TFLiteConverter.from_keras_model(blue_model)
        tflite_blue = converter_blue.convert()
        with open('blue_ball_model.tflite', 'wb') as f:
            f.write(tflite_blue)
        print("Blue Expert TFLite: Success.")
    
    print("All models exported. Note: pool_discriminator.pkl must be handled separately.")

if __name__ == '__main__':
    convert_models()