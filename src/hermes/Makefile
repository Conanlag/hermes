CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17

TARGET = hermes

SRC = src/main.cpp

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