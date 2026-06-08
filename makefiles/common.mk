ifndef COMMON_MK
COMMON_MK := 1

C_RESET := \033[0m
C_BOLD := \033[1m
C_DIM := \033[2m
C_RED := \033[31m
C_GREEN := \033[32m
C_YELLOW := \033[33m
C_BLUE := \033[34m
C_MAGENTA := \033[35m
C_CYAN := \033[36m

FLUTTER ?= flutter
DART ?= dart
NPM ?= npm
NPX ?= npx

PUB_GET := $(FLUTTER) pub get
DART_FORMAT := $(DART) format
DART_FIX := $(DART) fix
FLUTTER_ANALYZE := $(FLUTTER) analyze
FLUTTER_TEST := $(FLUTTER) test
PRETTIER := $(NPX) prettier

DART_FORMAT_PATHS ?= .
PRETTIER_GLOBS ?= **/*.{md,yml,yaml,json}

PRINT_HEADER = printf "\n$(C_BOLD)$(C_BLUE)%s$(C_RESET)\n\n"
PRINT_STEP = printf "$(C_BOLD)$(C_CYAN)==>$(C_RESET) %s\n"
PRINT_OK = printf "$(C_GREEN)OK$(C_RESET) %s\n"
PRINT_WARN = printf "$(C_YELLOW)WARN$(C_RESET) %s\n"
PRINT_ERROR = printf "$(C_RED)ERROR$(C_RESET) %s\n"

endif
