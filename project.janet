(declare-project
  :name "journo"
  :version "v0.0.1"
  :description "A Janet library for for building interactive, interview-style CLI interfaces."
  :dependencies ["https://github.com/janet-lang/spork"
                 "https://github.com/ianthehenry/judge"])

(declare-source
  :prefix "journo"
  :source ["src/init.janet"
           "src/journo.janet"
           "src/schemas.janet"
           "src/termcodes.janet"
           "src/color.janet"
           "src/utils.janet"])
