(use judge)

(deftest-type termux
  :setup    (fn [ ] (os/shell "tmux -u new-session -d -x 120 -y 24 -s test-journo") 
                    (os/sleep 4))
  :reset    (fn [_] (os/shell "tmux send -t test-journo clear ENTER"))
  :teardown (fn [_] (os/shell "tmux kill-session -t test-journo")
                    (os/rm "output")))

(deftest: termux "Test basic output" [_]
  (os/shell "tmux send -t test-journo janet SPACE example/example.janet ENTER")
  (os/sleep 0.5)
  (os/shell "tmux capture-pane -p > output")

  (test (freeze (slurp "output")) 
        ``
        [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
        [TEST] Please answer the following questions.
        
        ------------------------
        
         ? What is your favorite color?
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        ``)
  
  (os/shell "tmux send -t test-journo blue ENTER")
  (os/sleep 0.5)
  (os/shell "tmux capture-pane -p > output")

  (test (freeze (slurp "output")) 
        ``
        [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
        [TEST] Please answer the following questions.
        
        ------------------------
        
         ? What is your favorite color? blue
         ? Please set a password
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        ``)
  
  (os/shell "tmux send -t test-journo blue ENTER")
  (os/sleep 0.5)
  (os/shell "tmux capture-pane -p > output")

  (test (freeze (slurp "output")) 
        ``
        [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
        [TEST] Please answer the following questions.
        
        ------------------------
        
         ? What is your favorite color? blue
         ? Please set a password ****
         ? Pizza or icecream? (Use arrow keys to move, <enter> to confirm)
          » Pizza
            Icecream
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        ``)
  
  (os/shell "tmux send -t test-journo ENTER")
  (os/sleep 0.5)
  (os/shell "tmux capture-pane -p > output")

  (test (freeze (slurp "output")) 
        ``
        [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
        [TEST] Please answer the following questions.
        
        ------------------------
        
         ? What is your favorite color? blue
         ? Please set a password ****
         ? Pizza or icecream? Pizza
         ? Check all that apply (Use arrow keys to move, <space> to select, <a> toggles all, <i> inverts current selection)
          » ○ Overworked
            ○ Underpaid
            ○ Insides Out
            ○ Outsides In
        
        
        
        
        
        
        
        
        
        
        
        
        ``)
  
  (os/shell "tmux send -t test-journo SPACE") 
  (os/shell "tmux send -t test-journo ENTER")
  (os/sleep 0.5)
  (os/shell "tmux capture-pane -p > output")

  (test (freeze (slurp "output")) 
        ``
        [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
        [TEST] Please answer the following questions.
        
        ------------------------
        
         ? What is your favorite color? blue
         ? Please set a password ****
         ? Pizza or icecream? Pizza
         ? Check all that apply Overworked
        
        ------------------------
        
        Got these answers:
        
        What is your favorite color?
          blue
        Please set a password
          blue
        Pizza or icecream?
          Pizza
        Check all that apply
          @["Overworked"]
        
        [caleb@UBUNTU-22.04 ~/projects/janet/journo]
        
        ``))