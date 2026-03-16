# Environment configuration for SRAM generation
# Update these paths to match your local installation

# PDK Configuration
PDK_ROOT ?= $(HOME)/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
PDK ?= sky130A

# OpenRAM Configuration
OPENRAM_HOME ?= $(HOME)/OpenRAM/compiler
OPENRAM_TECH ?= $(HOME)/OpenRAM/technology

# Python Path for OpenRAM
export PYTHONPATH := $(OPENRAM_HOME):$(OPENRAM_TECH)/sky130:$(OPENRAM_TECH)/sky130/custom
