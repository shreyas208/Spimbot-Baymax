# Spimbot Baymax

### Submitted as LabSpimbot for CS 233 Computer Architecture, Fall 2016, University of Illinois at Urbana-Champaign
### by Bliss Chapman, Apoorva Dixit, and Shreyas Patil

### *Strategy*
After writing a complex bot that uses a computationally expensive decision making process to allocate its time and resources to best match its limited knowledge of the environment, we decided to switch to a strategy that spends the vast majority of it’s time generating resources to plant, water, and harvest.

We request three puzzles (empirically best results) at a time and solve as many as are available in each iteration of a loop that uses less than five branches to harvest, plant, or water the tile currently beneath the bot.  Our movement logic is incredibly cheap, just using a bonk interrupt to bounce in a repeated “diagonal square” that minimizes the potential fire damage while maximizing the total number of crops harvested. Additionally, we have slightly optimized our puzzle solving logic by inlining all function calls.