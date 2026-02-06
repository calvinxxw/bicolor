RED_WINDOW = None
BLUE_WINDOW = None
SEQ_LEN = 15

ALPHA_R = 1.0
BETA_R = 5.5
ALPHA_B = 1.0
BETA_B = 15.0


def select_context(df, window, seq_len):
    if window is None:
        return df.copy().reset_index(drop=True)
    return df.tail(window + seq_len).copy().reset_index(drop=True)
