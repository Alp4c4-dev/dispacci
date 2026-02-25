# Dispacci – Portale

**Overview**
Dispacci is a web portal built with Ruby on Rails that serves as the digital home for the editorial project *Dispacci dal fronte della resistenza*. The application features a distinctive terminal-style interface and integrates narrative content with interactive, game-like elements.

**Core Features**
* **Terminal-Style Interface:** A custom-designed UI that mimics a command-line environment, providing an immersive narrative experience.
* **Keyword Unlock System:** Content is progression-gated, requiring users to discover and enter specific keywords to advance the story.
* **Narrative Engine:** Content is dynamically loaded via seed files (.txt), allowing for efficient management of the storyline.
* **User Progress Tracking:** System to manage user accounts and save their current stage within the experience.
* **Interactive Elements:** Integration of ludic components that bridge the gap between a standard web portal and a narrative game.

**Tech Stack**
* **Framework:** Ruby on Rails 8.1
* **Language:** Ruby
* **Database:** SQLite (Development) / PostgreSQL (Production)
* **Frontend:** ERB with Hotwire (Turbo / Stimulus)
* **Asset Management:** Importmap
* **Styling:** Custom CSS

**Getting Started**
*Ensure you have Ruby and Bundler installed on your system.*

1. Clone the repository:
   `git clone https://github.com/Alp4c4-dev/dispacci.git`
2. Install the necessary gems:
   `bundle install`
3. Setup the database and load narrative content:
   `bin/rails db:setup`
4. Start the Rails server:
   `bin/rails server`
5. Access the portal at `http://localhost:3000`

**Development Status**
This is an experimental project in active development. Future iterations will focus on expanding the interactive narrative mechanics and refining the terminal UI.
