(use judge)
(use sh)

(deftest-type termux
  :setup    (fn [ ] ($ tmux -u new-session -d -x 120 -y 24 -s test-journo)
                    (while (not= ($<_ tmux capture-pane -p)
                                 "[caleb@UBUNTU-22.04 ~/projects/janet/journo]")
                      (os/sleep 0.5)))
  :reset    (fn [_] ($ tmux send -t test-journo clear ENTER))
  :teardown (fn [_] ($ tmux kill-session -t test-journo)))

(deftest: termux "Test basic output" [_]
  ($ tmux send -t test-journo janet SPACE example/example.janet ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color?
  `)
  
  ($ tmux send -t test-journo blue ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
    [caleb@UBUNTU-22.04 ~/projects/janet/journo] janet example/example.janet
    [TEST] Please answer the following questions.
    
    ------------------------
    
     ? What is your favorite color? blue
     ? Please set a password
  `)
  
  ($ tmux send -t test-journo blue ENTER)
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
  
  ($ tmux send -t test-journo ENTER)
  (os/sleep 0.5)

  (test-stdout (print ($<_ tmux capture-pane -p)) `
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
  `)
  
  ($ tmux send -t test-journo SPACE) 
  ($ tmux send -t test-journo ENTER)
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