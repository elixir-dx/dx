# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :dx, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:dx, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env()}.exs"

config :elixir,
  ansi_syntax_colors: [
    atom: :cyan,
    binary: :default_color,
    boolean: :magenta,
    charlist: :yellow,
    list: :default_color,
    map: :default_color,
    nil: :magenta,
    number: :yellow,
    string: :green,
    tuple: :default_color,
    # default: :light_cyan
    variable: :yellow,
    call: :default_color,
    operator: :default_color
  ]
