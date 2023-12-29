(use judge)
(use sh)

(deftest-type termux
  :setup    (fn [ ] ($ tmux -u new-session -d -x 80 -y 24 -s test-journo2)
                    (while (not= ($<_ tmux capture-pane -p)
                                 "[caleb@UBUNTU-22.04 ~/projects/janet/journo]")
                      (os/sleep 0.5))
                    ($ tmux send -t test-journo2 tput SPACE)
                    ($ tmux send -t test-journo2 smam ENTER)
                    (os/sleep 1))
  :reset    (fn [_] ($ tmux send -t test-journo2 clear ENTER))
  :teardown (fn [_] ($ tmux kill-session -t test-journo2)
                    (os/sleep 2)))

(deftest: termux "Test basic output" [_]
  ($ tmux send -t test-journo2 janet SPACE example/example.janet ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color?
  `)
  
  ($ tmux send -t test-journo2 blue ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color? blue
     ? Please set a password
  `)
  
  ($ tmux send -t test-journo2 blue ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color? blue
     ? Please set a password ****
     ? Pizza or icecream? (Use arrow keys to move, <enter> to confirm)
      » Pizza
        Icecream
  `)
  
  ($ tmux send -t test-journo2 ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color? blue
     ? Please set a password ****
     ? Pizza or icecream? Pizza
     ? Check all that apply (Use arrow keys to move, <space> to select, <a> toggles
     all, <i> inverts current selection)
      » ○ Overworked
        ○ Underpaid
        ○ Insides Out
        ○ Outsides In
  `)
  
  ($ tmux send -t test-journo2 SPACE) 
  ($ tmux send -t test-journo2 ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
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
  `)
  ($ tmux send -t test-journo2 janet SPACE example/example.janet ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
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
    
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color?
  `)
  
  ($ tmux send -t test-journo2 blue ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
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
    
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color? blue
     ? Please set a password
  `)
  
  ($ tmux send -t test-journo2 blue ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    
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
    
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color? blue
     ? Please set a password ****
     ? Pizza or icecream? (Use arrow keys to move, <enter> to confirm)
      » Pizza
        Icecream
  `)
  
  ($ tmux send -t test-journo2 ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    
    What is your favorite color?
      blue
    Please set a password
      blue
    Pizza or icecream?
      Pizza
    Check all that apply
      @["Overworked"]
    
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color? blue
     ? Please set a password ****
     ? Pizza or icecream? Pizza
     ? Check all that apply (Use arrow keys to move, <space> to select, <a> toggles
     all, <i> inverts current selection)
      » ○ Overworked
        ○ Underpaid
        ○ Insides Out
        ○ Outsides In
  `)
  
  ($ tmux send -t test-journo2 SPACE) 
  ($ tmux send -t test-journo2 ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
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
  `))