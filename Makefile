PREREQ = Text::Markdown Text::Xslate YAML Text::Unidecode

cpanm:
	@echo "Installing perl dependencies via cpanm"
	sudo cpanm $(PREREQ)
