#!/bin/bash

echo "Debug: Testing space counts"

# Test 1: ESC+5 + ESC+8 = 13 total
echo -e "Test line\n.\nw debug_test.txt\nq" | ./ed > /dev/null 2>&1
printf "\033" | ./ed debug_test.txt > /dev/null 2>&1 << 'EOF'
a
x<ESC>5<ESC>8y
.
w debug_test.txt
q
EOF

echo "Content of file after ESC+5 ESC+8:"
cat debug_test.txt

# Count spaces between x and y
spaces=$(sed -n 's/x\( *\)y/\1/p' debug_test.txt | wc -c)
echo "Spaces found: $((spaces-1))"  # subtract 1 for newline

rm -f debug_test.txt
