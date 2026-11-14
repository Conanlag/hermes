CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17 -Iinclude

TARGET = hermes

SRC = $(shell find src -type f -name '*.cpp')

INSTALL_DIR = $(HOME)/.local/bin

all: init-config

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -pthread $(LDFLAGS) -o $(TARGET)

init-config: $(TARGET)
	./$(TARGET) --init-config

clean:
	rm -f $(TARGET)

install: init-config
	mkdir -p $(INSTALL_DIR)
	cp $(TARGET) $(INSTALL_DIR)/$(TARGET)

uninstall:
	rm -f $(INSTALL_DIR)/$(TARGET)

.PHONY: all init-config clean install uninstall