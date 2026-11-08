import string

def extract_strings(filepath, min_len=4):
    with open(filepath, 'rb') as f:
        data = f.read()
    
    current = []
    for byte in data:
        char = chr(byte)
        if char in string.printable and byte >= 32 and byte <= 126:
            current.append(char)
        else:
            if len(current) >= min_len:
                yield "".join(current)
            current = []
    if len(current) >= min_len:
        yield "".join(current)

filepath = "assets/models/grading_model.tflite"
print(f"Extracting strings from {filepath}:")
all_strings = list(extract_strings(filepath))

# Print strings that look like tensor names, classes, or metadata
keywords = ["input", "output", "dense", "conv", "softmax", "label", "class", "gabah", "kopi", "sawit", "grade", "quality", "tbs"]
found_keywords = []
for s in all_strings:
    s_lower = s.lower()
    if any(k in s_lower for k in keywords) or len(s) < 20:
        found_keywords.append(s)

# Print a subset of interesting strings
print("\n--- Sample Strings (first 100) ---")
for s in all_strings[:100]:
    print(s)

print("\n--- Strings containing keywords or short strings (last 100) ---")
for s in found_keywords[-100:]:
    print(s)
