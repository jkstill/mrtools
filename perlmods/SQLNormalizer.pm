
# SQLNormalizer.pm
package SQLNormalizer;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = {}; # A simple hash reference to hold instance data (none needed here)
    bless $self, $class; # Bless the hash reference into the package
    return $self;
}

# Method: normalize
# Purpose: Takes a raw SQL string and applies a series of normalization rules
#          to produce a canonical form. This is useful for grouping semantically
#          similar SQL statements that may differ only in literals, whitespace, or case.
# Parameters:
#   $self      - The object instance (standard Perl object method first argument)
#   $sql_text  - The original SQL text string to be normalized.
# Returns:
#   A string containing the normalized SQL text.
sub normalize {
    my ($self, $sql_text) = @_;

    # Ensure $sql_text is defined; convert to empty string if undef to prevent issues.
    my $normalized_sql = defined $sql_text ? $sql_text : '';

    # 1. Remove comments
    # Remove multi-line block comments /* ... */
    # The 's' flag allows '.' to match newline characters.
    # The 'g' flag means replace all occurrences.
    # The '?' makes it non-greedy, so '/*' matches the *next* '*/'.
    $normalized_sql =~ s#/\*.*?\*/# #gs;

    # Remove single-line comments -- to end of line
    # The 'g' flag means replace all occurrences.
    $normalized_sql =~ s#--.*##g;

    # 2. Standardize whitespace
    # Replace any sequence of whitespace characters (spaces, tabs, newlines, carriage returns)
    # with a single space.
    $normalized_sql =~ s/\s+/ /g;

    # Trim leading whitespace.
    $normalized_sql =~ s/^\s+//;
    # Trim trailing whitespace.
    $normalized_sql =~ s/\s+$//;

    # 3. Normalize case to uppercase
    # This makes 'select' and 'SELECT' normalize to the same form.
    $normalized_sql = uc($normalized_sql);

    # 4. Replace literals with consistent placeholders
    # The order of these replacements can be important to avoid incorrect matches.
    # More specific patterns (e.g., date literals) should generally come before
    # more general patterns (e.g., string literals) if they contain similar
    # characters or structures.

    # Numeric literals: integers and floats (e.g., 123, 123.45, .5, 5.)
    # \b ensures we match whole "words" to avoid replacing parts of identifiers (e.g., 'COL123').
    # Handles numbers that start with a decimal (e.g., .5)
    $normalized_sql =~ s/\b\d+\.?\d*\b|\b\.\d+\b/NUM_LITERAL/g;

    # String literals: single quoted strings.
    # This regex is designed to be more robust, handling escaped single quotes (e.g., 'O''Malley').
    # It matches a single quote, then any sequence of characters that are not a single quote,
    # OR two consecutive single quotes (which represents an escaped quote),
    # and finally ends with a single quote.
    $normalized_sql =~ s/'(?:[^']|'')*'/STR_LITERAL/g;

    # DATE/TIMESTAMP literals: (e.g., DATE '2023-01-15', TIMESTAMP '2023-01-15 10:00:00')
    # These often involve a keyword followed by a string literal.
    # We replace the entire construct.
    $normalized_sql =~ s/\bDATE\s+STR_LITERAL\b/DATE_LITERAL/g;
    $normalized_sql =~ s/\bTIMESTAMP\s+STR_LITERAL\b/TIMESTAMP_LITERAL/g;

    # IN clause lists: (e.g., IN (1, 2, 3), IN ('A', 'B'))
    # This regex looks for the 'IN' keyword, followed by optional whitespace,
    # and then a pair of parentheses containing any characters (non-greedy match).
    # It uses a capture group ($1) for 'IN\s*' to retain that part.
    $normalized_sql =~ s/(IN\s*)\([^)]*\)/$1(IN_LIST_LITERAL)/g;

    return $normalized_sql;
}

# Method: generate_signature
# Purpose: Generates a "signature" (checksum) for a given SQL statement.
#          This signature is based on the normalized SQL text.
# Parameters:
#   $self      - The object instance.
#   $sql_text  - The original SQL text string for which to generate a signature.
# Returns:
#   A hexadecimal string representing a basic checksum of the normalized SQL.
# Note:
#   This is a *very basic* non-cryptographic checksum, specifically chosen to
#   avoid external Perl module dependencies. It is prone to collisions.
#   For robust, cryptographically secure hashing (e.g., MD5, SHA), you would typically
#   use Perl modules like Digest::MD5 or Digest::SHA if dependencies were allowed.
sub generate_signature {
    my ($self, $sql_text) = @_;
    # First, normalize the SQL text using the normalize method.
    my $normalized_sql = $self->normalize($sql_text);

    # Calculate a simple checksum (sum of ASCII values).
    my $checksum = 0;
    foreach my $char (split //, $normalized_sql) {
        $checksum += ord($char);
    }

    # Return the checksum as an 8-character hexadecimal string,
    # masking to 32 bits (0xFFFFFFFF) to keep it consistent in size
    # and mimic a common hash output format, though it's not a true hash.
    return sprintf("%08X", $checksum & 0xFFFFFFFF);
}

1;

