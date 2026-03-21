$(document).ready(function () {
  let translations = {
    title: "AIRSOFT ARENA",
    subtitle: "Leaderboard",
    columnPlayer: "Player",
    columnTeam: "Team",
    teamTotals: "Team Totals",
    totalKills: "Total Kills",
    noPlayers: "No players yet",
    team1: "Team 1",
    team2: "Team 2",
    noTeam: "No Team",
    ffa: "FFA",
  };
  const killfeedLifetimeMs = 4000;
  const defaultAccentColor = "#EC213A";

  function normalizeHexColor(value) {
    if (typeof value !== "string") {
      return defaultAccentColor;
    }

    const color = value.trim();
    if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(color)) {
      return color.toUpperCase();
    }

    return defaultAccentColor;
  }

  function hexToRgb(hexColor) {
    let hex = normalizeHexColor(hexColor).replace("#", "");
    if (hex.length === 3) {
      hex = hex
        .split("")
        .map((ch) => ch + ch)
        .join("");
    }

    const r = parseInt(hex.slice(0, 2), 16);
    const g = parseInt(hex.slice(2, 4), 16);
    const b = parseInt(hex.slice(4, 6), 16);
    return `${r}, ${g}, ${b}`;
  }

  function applyAccentTheme(accentColor) {
    const color = normalizeHexColor(accentColor);
    document.documentElement.style.setProperty("--accent-color", color);
    document.documentElement.style.setProperty("--accent-rgb", hexToRgb(color));
  }

  applyAccentTheme(defaultAccentColor);

  function applyStaticTranslations() {
    $("#leaderboard-title").text(`🎯 ${translations.title}`);
    $("#leaderboard-subtitle").text(translations.subtitle);
    $("#col-player").text(translations.columnPlayer);
    $("#col-team").text(translations.columnTeam);
  }

  applyStaticTranslations();

  // Listen for messages from the Lua client
  window.addEventListener("message", function (event) {
    const data = event.data;

    if (data.action === "setLeaderboardTranslations" && data.translations) {
      translations = {
        ...translations,
        ...data.translations,
      };
      applyStaticTranslations();
    }

    if (data.action === "setUiTheme") {
      applyAccentTheme(data.accentColor);
    }

    // Handle showing/hiding the leaderboard
    if (data.action === "showLeaderboard") {
      if (data.accentColor) {
        applyAccentTheme(data.accentColor);
      }

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

    if (data.action === "showKillFeed") {
      showKillFeedEntry(data.killer, data.victim);
    }

    if (data.action === "updateTimer") {
      updateTimer(data.secondsRemaining);
    }

    if (data.action === "timerExpired") {
      timerExpired();
    }

    if (data.action === "hideTimer") {
      $("#timer-display").hide();
    }
  });

  // Timer functions
  function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes}:${secs.toString().padStart(2, "0")}`;
  }

  function updateTimer(secondsRemaining) {
    const timerDisplay = $("#timer-display");
    const timerText = $("#timer-text");

    if (timerDisplay.css("display") === "none") {
      timerDisplay.show();
    }

    timerText.text(formatTime(secondsRemaining));

    // Add warning animation if 60 seconds or less
    if (secondsRemaining <= 60) {
      timerDisplay.addClass("timer-warning");
    } else {
      timerDisplay.removeClass("timer-warning");
    }
  }

  function timerExpired() {
    const timerDisplay = $("#timer-display");
    const timerText = $("#timer-text");

    timerText.text("00:00");
    timerDisplay.addClass("timer-warning");

    setTimeout(() => {
      timerDisplay.hide();
      timerDisplay.removeClass("timer-warning");
    }, 5000);
  }

  function showKillFeedEntry(killer, victim) {
    if (!killer || !victim) {
      return;
    }

    const killfeed = $("#killfeed");
    const entry = $(
      `<div class="killfeed-entry"><span class="killfeed-killer">${escapeHtml(killer)}</span> <span class="killfeed-verb">killed</span> <span class="killfeed-victim">${escapeHtml(victim)}</span></div>`,
    );

    killfeed.append(entry);

    setTimeout(() => {
      entry.addClass("fade-out");
      setTimeout(() => entry.remove(), 250);
    }, killfeedLifetimeMs);
  }

  // Function to update leaderboard with player data
  function updateLeaderboard(leaderboard) {
    const tbody = $("#leaderboard-body");
    tbody.empty();

    if (!leaderboard || leaderboard.length === 0) {
      tbody.append(
        `<tr><td colspan="6" class="no-data">${escapeHtml(
          translations.noPlayers,
        )}</td></tr>`,
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
          teamDisplay = `<span class="team-badge team-blue">${escapeHtml(
            translations.team1,
          )}</span>`;
          teamClass = "team-blue-row";
        } else if (player.team === "team2") {
          teamDisplay = `<span class="team-badge team-red">${escapeHtml(
            translations.team2,
          )}</span>`;
          teamClass = "team-red-row";
        } else {
          teamDisplay = `<span class="team-badge team-none">${escapeHtml(
            translations.noTeam,
          )}</span>`;
          teamClass = "team-none-row";
        }
        rowClass += " " + teamClass;
      } else {
        teamDisplay = `<span class="team-badge team-ffa">${escapeHtml(
          translations.ffa,
        )}</span>`;
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

    if (teamsMode) {
      const team1Kills = Number.isFinite(leaderboard[0]?.team1Kills)
        ? leaderboard[0].team1Kills
        : 0;
      const team2Kills = Number.isFinite(leaderboard[0]?.team2Kills)
        ? leaderboard[0].team2Kills
        : 0;

      tbody.append(`
                <tr class="team-summary-block-title">
                    <td colspan="6" class="team-summary-block-title-cell">${escapeHtml(translations.teamTotals)}</td>
                </tr>
            `);

      tbody.append(`
                <tr class="team-summary-header-row">
                    <td colspan="3" class="team-summary-header-cell">${escapeHtml(translations.columnTeam)}</td>
                    <td colspan="3" class="team-summary-header-cell">${escapeHtml(translations.totalKills)}</td>
                </tr>
            `);

      tbody.append(`
                <tr class="team-summary-row team-blue-summary">
                    <td colspan="3" class="team-summary-label">${escapeHtml(translations.team1)}</td>
                    <td colspan="3" class="team-summary-value">${team1Kills}</td>
                </tr>
            `);

      tbody.append(`
                <tr class="team-summary-row team-red-summary">
                    <td colspan="3" class="team-summary-label">${escapeHtml(translations.team2)}</td>
                    <td colspan="3" class="team-summary-value">${team2Kills}</td>
                </tr>
            `);
    }
  }

  // Function to escape HTML to prevent XSS
  function escapeHtml(text) {
    text = String(text ?? "");
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
