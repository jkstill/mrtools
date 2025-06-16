#!/usr/bin/perl

use strict;
use warnings;
use lib './';
use SQLNormalizer; # This loads your module

# Create an instance of the SQL normalizer
my $normalizer = SQLNormalizer->new();

# Example SQL statements you might extract from a trace file
my @raw_sql_statements = (
    "SELECT order_id, customer_name FROM orders WHERE order_value > 1000 AND order_date = DATE '2024-06-15';",
    "select ORDER_ID, CUSTOMER_NAME from Orders where order_value > 2000 and order_date = DATE '2024-06-16' /* Some comment */;",
    "INSERT INTO log_table (message, timestamp) VALUES ('Processing record 123', SYSDATE);",
    "INSERT INTO log_table (message, timestamp) VALUES ('Processing record 456', SYSDATE);",
    "UPDATE products SET price = 9.99 WHERE product_id IN (10, 20, 30);",
    "UPDATE products SET price = 12.50 WHERE product_id IN (40, 50); -- Different literals, same structure",
    "SELECT /* Another query */ column_a, column_b FROM my_table WHERE some_id = 789;"
);

print "--- Processing SQL Statements ---\n";

my %sql_groups; # Hash to store aggregated data by custom signature

foreach my $sql (@raw_sql_statements) {
    my $normalized_sql = $normalizer->normalize($sql);
    my $custom_signature = $normalizer->generate_signature($sql);

    print "\nOriginal SQL: '$sql'\n";
    print "Normalized SQL: '$normalized_sql'\n";
    print "Custom Signature: $custom_signature\n";

    # Aggregate counts and store a sample of the original SQL
    $sql_groups{$custom_signature}{count}++;
    # Store the first original SQL encountered for this signature as a sample
    $sql_groups{$custom_signature}{sample_sql} = $sql unless exists $sql_groups{$custom_signature}{sample_sql};
}

print "\n--- Summary of SQL Groups by Custom Signature ---\n";
foreach my $sig (sort keys %sql_groups) {
    print "Signature: $sig\n";
    print "  Count: " . $sql_groups{$sig}{count} . "\n";
    print "  Sample Original SQL: '" . $sql_groups{$sig}{sample_sql} . "'\n";
}
