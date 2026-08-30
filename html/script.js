document.addEventListener("DOMContentLoaded", function () {
  let translations = {
    title: "AIRSOFT ARENA",
    subtitle: "Leaderboard",
    columnPlayer: "Player",
    columnTeam: "Team",
    columnTier: "Tier",
    teamTotals: "Team Totals",
    totalKills: "Total Kills",
    noPlayers: "No players yet",
    team1: "Team 1",
    team2: "Team 2",
    noTeam: "No Team",
    ffa: "FFA",
    firstToKills: "First to %{limit} kills",
    mvp: "MVP",
    bestStreak: "Best Streak",
    winReason: "Result",
    arenaBoardTitle: "Live Match",
  };
  const killfeedLifetimeMs = 4000;
  const defaultAccentColor = "#EC213A";
  const winReasonLabels = {
    score_limit: "Score limit reached",
    elimination: "Last player standing",
    gungame: "Gun game complete",
    timer: "Time expired",
    admin: "Match ended by admin",
    empty: "No players remaining",
  };

  function $(selector) {
    return document.querySelector(selector);
  }

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
    $("#leaderboard-title").textContent = `🎯 ${translations.title}`;
    $("#leaderboard-subtitle").textContent = translations.subtitle;
    $("#col-player").textContent = translations.columnPlayer;
    $("#col-team").textContent = translations.columnTeam;
    $("#col-tier").textContent = translations.columnTier;
    $("#final-col-player").textContent = translations.columnPlayer;
    $("#final-col-team").textContent = translations.columnTeam;
    $("#final-col-tier").textContent = translations.columnTier;
    $("#arena-board-title").textContent = translations.arenaBoardTitle;
  }

  applyStaticTranslations();

  function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${minutes}:${secs.toString().padStart(2, "0")}`;
  }

  function updateScoreLimitText(scoreLimit) {
    const scoreLimitText = $("#score-limit-text");
    const limit = Number(scoreLimit) || 0;

    if (limit > 0) {
      scoreLimitText.textContent = translations.firstToKills.replace(
        "%{limit}",
        String(limit),
      );
      scoreLimitText.style.display = "";
    } else {
      scoreLimitText.textContent = "";
      scoreLimitText.style.display = "none";
    }
  }

  function resetArenaHud() {
    $("#killfeed").innerHTML = "";
    $("#leaderboard").style.display = "none";
    const timerDisplay = $("#timer-display");
    timerDisplay.style.display = "none";
    timerDisplay.classList.remove("timer-warning");
    $("#timer-text").textContent = "10:00";
    updateScoreLimitText(0);
    document.querySelectorAll(".gungame-column").forEach((column) => {
      column.style.display = "none";
    });
  }

  function renderMatchRecap(recap) {
    const recapContainer = $("#match-recap");
    if (!recap || !recapContainer) {
      if (recapContainer) {
        recapContainer.style.display = "none";
        recapContainer.innerHTML = "";
      }
      return;
    }

    const reason = winReasonLabels[recap.reason] || recap.reason || "";
    const mvpName = recap.mvp && recap.mvp.name ? recap.mvp.name : "-";
    const mvpKills = recap.mvp && recap.mvp.kills != null ? recap.mvp.kills : 0;
    const streakName =
      recap.bestStreak && recap.bestStreak.name ? recap.bestStreak.name : "-";
    const streakValue =
      recap.bestStreak && recap.bestStreak.streak != null
        ? recap.bestStreak.streak
        : 0;

    recapContainer.innerHTML = `
      <div class="recap-line"><span>${escapeHtml(translations.winReason)}:</span> ${escapeHtml(reason)}</div>
      <div class="recap-line"><span>${escapeHtml(translations.mvp)}:</span> ${escapeHtml(mvpName)} (${mvpKills} K)</div>
      <div class="recap-line"><span>${escapeHtml(translations.bestStreak)}:</span> ${escapeHtml(streakName)} (${streakValue})</div>
    `;
    recapContainer.style.display = "";
  }

  function renderArenaBoard(payload) {
    const board = $("#arena-board");
    if (!payload) {
      board.style.display = "none";
      return;
    }

    $("#arena-board-mode").textContent = payload.mode || "";
    $("#arena-board-timer").textContent = formatTime(
      Number(payload.timer) || 0,
    );

    const limit = Number(payload.scoreLimit) || 0;
    $("#arena-board-score-limit").textContent =
      limit > 0
        ? translations.firstToKills.replace("%{limit}", String(limit))
        : "";

    const rowsContainer = $("#arena-board-rows");
    rowsContainer.innerHTML = "";

    const rows = (payload.leaderboard || []).slice(0, 3);
    if (rows.length === 0) {
      rowsContainer.innerHTML = `<div class="arena-board-row">${escapeHtml(translations.noPlayers)}</div>`;
    } else {
      rows.forEach((player, index) => {
        const tierText =
          player.gunGameLevel && player.gunGameTotal
            ? ` · ${player.gunGameLevel}/${player.gunGameTotal}`
            : "";
        const row = document.createElement("div");
        row.className = "arena-board-row";
        row.innerHTML = `<span>#${index + 1} ${escapeHtml(player.name)}</span><span>${player.kills} K${tierText}</span>`;
        rowsContainer.appendChild(row);
      });
    }

    board.style.display = "";
  }

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

    if (data.action === "showLeaderboard") {
      if (data.accentColor) {
        applyAccentTheme(data.accentColor);
      }

      if (data.show) {
        updateLeaderboard(data.leaderboard);
        $("#leaderboard").style.display = "";
      } else {
        $("#leaderboard").style.display = "none";
      }
    }

    if (data.action === "showFinalScoreboard") {
      if (data.accentColor) {
        applyAccentTheme(data.accentColor);
      }

      if (data.show) {
        updateLeaderboard(data.leaderboard, "#final-leaderboard-body");
        renderMatchRecap(data.recap);
        $("#final-scoreboard-overlay").style.display = "";
      } else {
        renderMatchRecap(null);
        $("#final-scoreboard-overlay").style.display = "none";
      }
    }

    if (data.action === "updateLeaderboard") {
      updateLeaderboard(data.leaderboard);
    }

    if (data.action === "updateMatchHud") {
      if (data.scoreLimit != null) {
        updateScoreLimitText(data.scoreLimit);
      }
      if (data.timer != null) {
        updateTimer(data.timer);
      }
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

    if (data.action === "clearArenaHud") {
      resetArenaHud();
    }

    if (data.action === "hideTimer") {
      const timerDisplay = $("#timer-display");
      timerDisplay.style.display = "none";
      timerDisplay.classList.remove("timer-warning");
    }

    if (data.action === "showArenaBoard") {
      renderArenaBoard(data);
    }

    if (data.action === "hideArenaBoard") {
      $("#arena-board").style.display = "none";
    }
  });

  function updateTimer(secondsRemaining) {
    const timerDisplay = $("#timer-display");
    const timerText = $("#timer-text");

    if (timerDisplay.style.display === "none") {
      timerDisplay.style.display = "";
    }

    timerText.textContent = formatTime(secondsRemaining);

    if (secondsRemaining <= 60) {
      timerDisplay.classList.add("timer-warning");
    } else {
      timerDisplay.classList.remove("timer-warning");
    }
  }

  function timerExpired() {
    const timerDisplay = $("#timer-display");
    const timerText = $("#timer-text");

    timerText.textContent = "00:00";
    timerDisplay.classList.add("timer-warning");

    setTimeout(() => {
      timerDisplay.style.display = "none";
      timerDisplay.classList.remove("timer-warning");
    }, 5000);
  }

  function showKillFeedEntry(killer, victim) {
    if (!killer || !victim) {
      return;
    }

    const killfeed = $("#killfeed");
    const entry = document.createElement("div");
    entry.className = "killfeed-entry";
    entry.innerHTML = `<span class="killfeed-killer">${escapeHtml(killer)}</span> <span class="killfeed-verb">killed</span> <span class="killfeed-victim">${escapeHtml(victim)}</span>`;
    killfeed.appendChild(entry);

    setTimeout(() => {
      entry.classList.add("fade-out");
      setTimeout(() => entry.remove(), 250);
    }, killfeedLifetimeMs);
  }

  function closeFinalScoreboard() {
    fetch(`https://${GetParentResourceName()}/closeFinalScoreboard`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify({}),
    }).catch(() => {});
  }

  $("#final-scoreboard-close").addEventListener("click", function () {
    closeFinalScoreboard();
  });

  document.addEventListener("keydown", function (event) {
    if (
      event.key === "Escape" &&
      $("#final-scoreboard-overlay").style.display !== "none"
    ) {
      closeFinalScoreboard();
    }
  });

  function updateLeaderboard(
    leaderboard,
    targetBodySelector = "#leaderboard-body",
  ) {
    const tbody = document.querySelector(targetBodySelector);
    tbody.innerHTML = "";

    const gunGameMode = (leaderboard || []).some(
      (player) => player.gunGameTotal && player.gunGameTotal > 0,
    );
    document.querySelectorAll(".gungame-column").forEach((column) => {
      column.style.display = gunGameMode ? "" : "none";
    });

    const columnCount = gunGameMode ? 7 : 6;

    if (!leaderboard || leaderboard.length === 0) {
      const row = document.createElement("tr");
      row.innerHTML = `<td colspan="${columnCount}" class="no-data">${escapeHtml(
        translations.noPlayers,
      )}</td>`;
      tbody.appendChild(row);
      return;
    }

    const teamsMode = leaderboard.some((player) => player.team);

    leaderboard.sort((a, b) => {
      if (b.kills !== a.kills) {
        return b.kills - a.kills;
      }
      return b.kd - a.kd;
    });

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

      const tierCell =
        gunGameMode && player.gunGameTotal
          ? `<td class="tier">${player.gunGameLevel || 1}/${player.gunGameTotal}</td>`
          : gunGameMode
            ? `<td class="tier">-</td>`
            : "";

      const row = document.createElement("tr");
      row.className = rowClass;
      row.innerHTML = `
                <td class="rank ${rankClass}">#${rank}</td>
                <td class="player-name">${escapeHtml(player.name)}</td>
                <td class="team">${teamDisplay}</td>
                ${tierCell}
                <td class="kills">${player.kills}</td>
                <td class="deaths">${player.deaths}</td>
                <td class="kd">${kd}</td>
            `;
      tbody.appendChild(row);
    });

    if (teamsMode) {
      const team1Kills = Number.isFinite(leaderboard[0]?.team1Kills)
        ? leaderboard[0].team1Kills
        : 0;
      const team2Kills = Number.isFinite(leaderboard[0]?.team2Kills)
        ? leaderboard[0].team2Kills
        : 0;

      tbody.insertAdjacentHTML(
        "beforeend",
        `
                <tr class="team-summary-block-title">
                    <td colspan="${columnCount}" class="team-summary-block-title-cell">${escapeHtml(translations.teamTotals)}</td>
                </tr>
            `,
      );

      tbody.insertAdjacentHTML(
        "beforeend",
        `
                <tr class="team-summary-header-row">
                    <td colspan="${Math.ceil(columnCount / 2)}" class="team-summary-header-cell">${escapeHtml(translations.columnTeam)}</td>
                    <td colspan="${Math.floor(columnCount / 2)}" class="team-summary-header-cell">${escapeHtml(translations.totalKills)}</td>
                </tr>
            `,
      );

      tbody.insertAdjacentHTML(
        "beforeend",
        `
                <tr class="team-summary-row team-blue-summary">
                    <td colspan="${Math.ceil(columnCount / 2)}" class="team-summary-label">${escapeHtml(translations.team1)}</td>
                    <td colspan="${Math.floor(columnCount / 2)}" class="team-summary-value">${team1Kills}</td>
                </tr>
            `,
      );

      tbody.insertAdjacentHTML(
        "beforeend",
        `
                <tr class="team-summary-row team-red-summary">
                    <td colspan="${Math.ceil(columnCount / 2)}" class="team-summary-label">${escapeHtml(translations.team2)}</td>
                    <td colspan="${Math.floor(columnCount / 2)}" class="team-summary-value">${team2Kills}</td>
                </tr>
            `,
      );
    }
  }

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
