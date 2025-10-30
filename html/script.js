$(document).ready(function () {
  // Listen for messages from the Lua client
  window.addEventListener("message", function (event) {
    const data = event.data;

    // Handle showing/hiding the leaderboard
    if (data.action === "showLeaderboard") {
      if (data.show) {
        updateLeaderboard(data.leaderboard);
        $("#leaderboard").show();
      } else {
        $("#leaderboard").hide();
      }
    }

    // Handle updating the leaderboard data
    if (data.action === "updateLeaderboard") {
      updateLeaderboard(data.leaderboard);
    }
  });

  // Function to update leaderboard with player data
  function updateLeaderboard(leaderboard) {
    const tbody = $("#leaderboard-body");
    tbody.empty();

    if (!leaderboard || leaderboard.length === 0) {
      tbody.append(
        '<tr><td colspan="6" class="no-data">No players yet</td></tr>'
      );
      return;
    }

    // Check if any player has a team (to determine if teams mode is active)
    const teamsMode = leaderboard.some((player) => player.team);

    // Sort leaderboard by kills (descending), then by K/D ratio
    leaderboard.sort((a, b) => {
      if (b.kills !== a.kills) {
        return b.kills - a.kills;
      }
      return b.kd - a.kd;
    });

    // Generate leaderboard rows
    leaderboard.forEach((player, index) => {
      const rank = index + 1;
      const kd =
        player.deaths === 0
          ? player.kills.toFixed(2)
          : (player.kills / player.deaths).toFixed(2);

      let rowClass = "";
      let rankClass = "";
      let teamDisplay = "";
      let teamClass = "";

      // Add special styling for top 3 players
      if (rank === 1) {
        rowClass = "top-player";
        rankClass = "gold";
      } else if (rank === 2) {
        rowClass = "second-player";
        rankClass = "silver";
      } else if (rank === 3) {
        rowClass = "third-player";
        rankClass = "bronze";
      }

      // Handle team display
      if (teamsMode) {
        if (player.team === "team1") {
          teamDisplay = '<span class="team-badge team-blue">Team 1</span>';
          teamClass = "team-blue-row";
        } else if (player.team === "team2") {
          teamDisplay = '<span class="team-badge team-red">Team 2</span>';
          teamClass = "team-red-row";
        } else {
          teamDisplay = '<span class="team-badge team-none">No Team</span>';
          teamClass = "team-none-row";
        }
        rowClass += " " + teamClass;
      } else {
        teamDisplay = '<span class="team-badge team-ffa">FFA</span>';
      }

      const row = `
                <tr class="${rowClass}">
                    <td class="rank ${rankClass}">#${rank}</td>
                    <td class="player-name">${escapeHtml(player.name)}</td>
                    <td class="team">${teamDisplay}</td>
                    <td class="kills">${player.kills}</td>
                    <td class="deaths">${player.deaths}</td>
                    <td class="kd">${kd}</td>
                </tr>
            `;

      tbody.append(row);
    });
  }

  // Function to escape HTML to prevent XSS
  function escapeHtml(text) {
    const map = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;",
    };
    return text.replace(/[&<>"']/g, function (m) {
      return map[m];
    });
  }
});
