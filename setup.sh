# Get the absolute path of the current script using realpath or readlink
if command -v realpath >/dev/null 2>&1; then
    script_path=$(realpath "$0")
else
    script_path=$(readlink -f "$0")
fi

# Get the directory containing the script
script_dir=$(dirname "$script_path")

mkdir -p "$HOME/.config/nvim"

ln -sf "$script_dir/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$script_dir/.zshrc" "$HOME/.zshrc"
ln -sf "$script_dir/init.lua" "$HOME/.config/nvim/init.lua"
ln -sf "$script_dir/.vimrc" "$HOME/.vimrc"
ln -sf "$script_dir/.prettierrc.json" "$HOME/.prettierrc.json"

mkdir -p $HOME/.config/nvim/lua 
ln -sf "$script_dir/myplugins" "$HOME/.config/nvim/lua/myplugins"

mkdir -p $HOME/.config/kitty
ln -sf "$script_dir/kitty.conf" "$HOME/.config/kitty/kitty.conf"

ln -sf "$script_dir/ssh.config" "$HOME/.ssh/config"

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
echo "remember to Ctl-B I inside tmux to setup everything"

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

ln -sf "$script_dir/.gitconfig" "$HOME/.gitconfig"

# Setup Claude configuration
mkdir -p "$HOME/.claude"
ln -sf "$script_dir/claude/settings.json" "$HOME/.claude/settings.json"

# Append common Claude instructions to CLAUDE.md if not already present
if ! grep -q "# Common Claude Instructions" "$script_dir/CLAUDE.md"; then
    echo "" >> "$script_dir/CLAUDE.md"
    cat "$script_dir/claude/CLAUDE_INSTRUCTIONS.md" >> "$script_dir/CLAUDE.md"
fi
