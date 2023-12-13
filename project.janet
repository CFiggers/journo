(declare-project
  :name "journo"
  :description "A Janet library for creating Inquirer.js-like CLI interfaces."
  :dependencies ["https://github.com/janet-lang/spork"
                 "https://github.com/ianthehenry/judge"])

(declare-source
  :prefix "journo"
  :source ["src/init.janet"])
