CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17 -Iinclude

TARGET = hermes

SRC = $(shell find src -type f -name '*.cpp')

INSTALL_DIR = $(HOME)/.local/bin

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -pthread -o $(TARGET)

clean:
	rm -f $(TARGET)

install: $(TARGET)
	mkdir -p $(INSTALL_DIR)
	cp $(TARGET) $(INSTALL_DIR)/$(TARGET)

uninstall:
	rm -f $(INSTALL_DIR)/$(TARGET)

test: $(TARGET)
	@./tests/test.sh
	@bash ./tests/test_rf26.sh 10
	@bash ./tests/test_rf27.sh

.PHONY: all clean install uninstall test