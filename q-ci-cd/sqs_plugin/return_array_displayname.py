import re

# Your input text should be failed segements of mail report generated every day 
input_text = """
"""

# Regular expression to match the Display Name pattern
pattern = r"Display Name:\s*(.*?)\s*URL"

# Find all matches in the input text
display_names = list(re.findall(pattern, input_text))

# Print the result
print(len(display_names))
print(display_names)
