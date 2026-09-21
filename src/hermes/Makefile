CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17 -Iinclude

TARGET = hermes

SRC = $(shell find src -type f -name '*.cpp')


INSTALL_DIR = $(HOME)/.local/bin

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	mkdir -p $(INSTALL_DIR)
	cp $(TARGET) $(INSTALL_DIR)/$(TARGET)

uninstall:
	rm -f $(INSTALL_DIR)/$(TARGET)

.PHONY: all clean install uninstall