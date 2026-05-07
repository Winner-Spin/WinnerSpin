import sys

with open('lib/features/slot/presentation/views/game_rules_screen.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'const SizedBox(height: 12)' in line:
        idx = i
        break

# The structure we need is:
# 4 closing parens for Expanded, RawScrollbar, SingleChildScrollView, Column
# then ], for children
# then 6 closing parens for Column, ClipRRect, Container, ConstrainedBox, Align, Expanded

replacement = """                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ],
  ),
);
}
"""

lines = lines[:90] + [replacement] + lines[109:]

with open('lib/features/slot/presentation/views/game_rules_screen.dart', 'w') as f:
    f.writelines(lines)
