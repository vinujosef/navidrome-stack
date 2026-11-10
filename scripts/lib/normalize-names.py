"""Canonicalize built-in artist names within metadata values."""
import re
import sys


# Separators accept compact initials, periods, and whitespace. Boundaries
# keep matches inside multi-artist tags without changing longer names.
NAME_RULES = (
    (r"sam[\s.]*c[\s.]*s\.?", "Sam C. S."),
    (r"m[\s.]*g[\s.]*sreekumar", "M. G. Sreekumar"),
    (r"yuvan[\s.]*shankar[\s.]*raja", "Yuvan Shankar Raja"),
    (r"k[\s.]*g[\s.]*markose", "K. G. Markose"),
    (r"m[\s.]*g[\s.]*radhakrishnan", "M. G. Radhakrishnan"),
    (r"k[\s.]*s[\s.]*harisankar", "K. S. Harisankar"),
    (r"nikhita[\s.]*gandhi", "Nikhita Gandhi"),
    (r"a[\s.]*r[\s.]*rahman", "A. R. Rahman"),
    (r"neha[\s.]*(?:s[\s.]*)?nair", "Neha S. Nair"),
    (r"k[\s.]*s[\s.]*chith?ra", "K. S. Chithra"),
    (r"k[\s.]*j[\s.]*yesudas", "K. J. Yesudas"),
    (r"g[\s.]*v[\s.]*prakash?(?:[\s.]*kumar)?", "G. V. Prakash Kumar"),
    (r"sid[\s.]*(?:sriram|sriam|shriram)", "Sid Sriram"),
    (r"s[\s.]*p[\s.]*balasubrah?manyam", "S. P. Balasubrahmanyam"),
)


def normalize_names(value):
    for pattern, canonical in NAME_RULES:
        value = re.sub(r"(?<!\w)" + pattern + r"(?!\w)", canonical,
                       value, flags=re.IGNORECASE)
    return value


if __name__ == "__main__":
    sys.stdout.write(normalize_names(sys.stdin.read()))
