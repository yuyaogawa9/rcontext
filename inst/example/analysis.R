# Example: this script is BROKEN ON PURPOSE.
#
# Run it top to bottom in the RStudio console. The third line throws.
# Then, in the terminal, ask your agent:
#
#     "my script just errored - what happened and how do I fix it?"
#
# A context-aware agent will read the console error, inspect the data frame
# that is already loaded in your session, find the real column name, and
# hand you the corrected line. An agent without session context can only
# guess, because the column name it needs is nowhere in this file.

penguins <- read.csv("example/penguins.csv")

# The bug: this dataset does not use the palmerpenguins column names.
avg_bill <- aggregate(bill_length_mm ~ species, data = penguins, FUN = mean)

print(avg_bill)

boxplot(bill_length_mm ~ species, data = penguins,
        main = "Bill length by species",
        ylab = "Bill length (mm)")
