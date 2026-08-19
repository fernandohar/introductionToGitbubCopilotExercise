const POPULAR_US = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "TSLA", "META", "JPM"];
const POPULAR_HK = ["0700.HK", "9988.HK", "0005.HK", "3690.HK", "1810.HK", "9618.HK", "0941.HK", "2318.HK"];
const WATCHLIST_KEY = "stockAnalyzerWatchlist";

const state = {
  symbol: null,
  period: "1y",
  quote: null,
  history: null,
  fundamentals: null,
  trend: null,
  charts: {},
};

const $ = (id) => document.getElementById(id);

function formatNumber(value, decimals = 2) {
  if (value == null || Number.isNaN(value)) return "—";
  return Number(value).toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}

function formatLargeNumber(value) {
  if (value == null) return "—";
  const abs = Math.abs(value);
  if (abs >= 1e12) return `$${(value / 1e12).toFixed(2)}T`;
  if (abs >= 1e9) return `$${(value / 1e9).toFixed(2)}B`;
  if (abs >= 1e6) return `$${(value / 1e6).toFixed(2)}M`;
  return `$${formatNumber(value, 0)}`;
}

function formatPercent(value) {
  if (value == null) return "—";
  const sign = value >= 0 ? "+" : "";
  return `${sign}${formatNumber(value, 2)}%`;
}

function getWatchlist() {
  try {
    return JSON.parse(localStorage.getItem(WATCHLIST_KEY) || "[]");
  } catch {
    return [];
  }
}

function saveWatchlist(list) {
  localStorage.setItem(WATCHLIST_KEY, JSON.stringify(list));
}

function renderWatchlist() {
  const list = getWatchlist();
  const container = $("watchlist");
  container.innerHTML = "";

  if (!list.length) {
    container.innerHTML = '<li style="cursor:default;color:var(--text-muted)">No symbols saved</li>';
    return;
  }

  list.forEach((symbol) => {
    const li = document.createElement("li");
    li.innerHTML = `
      <span class="symbol">${symbol}</span>
      <button class="remove" type="button" aria-label="Remove ${symbol}">×</button>
    `;
    li.querySelector(".symbol").addEventListener("click", () => loadSymbol(symbol));
    li.querySelector(".remove").addEventListener("click", (event) => {
      event.stopPropagation();
      saveWatchlist(list.filter((item) => item !== symbol));
      renderWatchlist();
    });
    container.appendChild(li);
  });
}

function renderPopularChips() {
  renderChipGroup("popularChips", POPULAR_US);
  renderChipGroup("hkChips", POPULAR_HK);
}

function renderChipGroup(containerId, symbols) {
  const container = $(containerId);
  container.innerHTML = "";
  symbols.forEach((symbol) => {
    const btn = document.createElement("button");
    btn.className = "chip";
    btn.type = "button";
    btn.textContent = symbol.replace(".HK", "");
    btn.title = symbol;
    btn.addEventListener("click", () => {
      closeSidebar();
      loadSymbol(symbol);
    });
    container.appendChild(btn);
  });
}

function closeSidebar() {
  $("sidebar")?.classList.remove("open");
}

function setLoading(isLoading) {
  $("loading").classList.toggle("hidden", !isLoading);
}

function showPanels(show) {
  ["controls", "metrics", "tabBar", "overviewPanel"].forEach((id) => {
    $(id).classList.toggle("hidden", !show);
  });
}

async function api(path) {
  const response = await fetch(path);
  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    throw new Error(error.detail || "Request failed");
  }
  return response.json();
}

function destroyCharts() {
  Object.values(state.charts).forEach((chart) => chart.destroy());
  state.charts = {};
}

function chartDefaults() {
  Chart.defaults.color = "#8b97a8";
  Chart.defaults.borderColor = "rgba(255,255,255,0.08)";
  Chart.defaults.font.family = "'DM Sans', sans-serif";
}

function buildLineDataset(label, data, color, hidden = false) {
  return {
    label,
    data,
    borderColor: color,
    backgroundColor: "transparent",
    borderWidth: 2,
    pointRadius: 0,
    tension: 0.15,
    hidden,
  };
}

function renderHero(quote) {
  const changeClass = (quote.change ?? 0) >= 0 ? "positive" : "negative";
  $("hero").innerHTML = `
    <div class="hero-card">
      <div class="hero-top">
        <div>
          <div class="symbol">${quote.symbol}</div>
          <h2>${quote.name}</h2>
        </div>
        <div class="price-block">
          <div class="price">${formatNumber(quote.price)} ${quote.currency || ""}</div>
          <div class="change ${changeClass}">
            ${formatNumber(quote.change)} (${formatPercent(quote.change_percent)})
          </div>
          ${quote.source ? `<div class="data-source">Data: ${quote.source}</div>` : ""}
        </div>
      </div>
    </div>
  `;
}

function renderMetrics(history) {
  const summary = history.summary || {};
  const signals = history.signals || {};
  const items = [
    { label: "Latest Close", value: formatNumber(summary.latest_close) },
    { label: "RSI (14)", value: formatNumber(summary.rsi, 1) },
    { label: "SMA 20", value: formatNumber(summary.sma20) },
    { label: "SMA 50", value: formatNumber(summary.sma50) },
    { label: "SMA 200", value: formatNumber(summary.sma200) },
    { label: "Signal", value: (signals.overall || "neutral").toUpperCase() },
  ];

  $("metrics").innerHTML = items
    .map(
      (item) => `
      <div class="metric-card">
        <div class="label">${item.label}</div>
        <div class="value">${item.value}</div>
      </div>
    `
    )
    .join("");
}

function renderSignalBanner(signals) {
  const banner = $("signalBanner");
  const overall = signals.overall || "neutral";
  banner.className = `signal-banner ${overall}`;
  banner.innerHTML = `
    <strong>${overall.toUpperCase()} outlook</strong>
    <div style="margin-top:6px;color:var(--text-muted)">
      RSI: ${signals.rsi ?? "—"} · MA trend: ${signals.ma_cross ?? "—"}
    </div>
  `;
}

function renderCharts(history) {
  destroyCharts();
  chartDefaults();

  const rows = history.history || [];
  const labels = rows.map((row) => row.date);

  const priceCtx = $("priceChart").getContext("2d");
  state.charts.price = new Chart(priceCtx, {
    type: "line",
    data: {
      labels,
      datasets: [
        buildLineDataset("Close", rows.map((r) => r.close), "#3b82f6"),
        buildLineDataset("SMA 20", rows.map((r) => r.sma20), "#22c55e"),
        buildLineDataset("SMA 50", rows.map((r) => r.sma50), "#eab308"),
        buildLineDataset("SMA 200", rows.map((r) => r.sma200), "#a855f7", true),
      ],
    },
    options: {
      responsive: true,
      interaction: { mode: "index", intersect: false },
      plugins: { legend: { position: "bottom" } },
      scales: {
        x: { ticks: { maxTicksLimit: 8 } },
        y: { ticks: { callback: (v) => formatNumber(v) } },
      },
    },
  });

  const volumeCtx = $("volumeChart").getContext("2d");
  state.charts.volume = new Chart(volumeCtx, {
    type: "bar",
    data: {
      labels,
      datasets: [
        {
          label: "Volume",
          data: rows.map((r) => r.volume),
          backgroundColor: "rgba(59, 130, 246, 0.35)",
        },
      ],
    },
    options: {
      responsive: true,
      plugins: { legend: { display: false } },
      scales: { x: { ticks: { maxTicksLimit: 8 } } },
    },
  });

  const rsiCtx = $("rsiChart").getContext("2d");
  state.charts.rsi = new Chart(rsiCtx, {
    type: "line",
    data: {
      labels,
      datasets: [buildLineDataset("RSI", rows.map((r) => r.rsi), "#f97316")],
    },
    options: {
      responsive: true,
      plugins: { legend: { display: false } },
      scales: {
        y: { min: 0, max: 100 },
        x: { ticks: { maxTicksLimit: 6 } },
      },
    },
  });

  const macdCtx = $("macdChart").getContext("2d");
  state.charts.macd = new Chart(macdCtx, {
    type: "line",
    data: {
      labels,
      datasets: [
        buildLineDataset("MACD", rows.map((r) => r.macd), "#3b82f6"),
        buildLineDataset("Signal", rows.map((r) => r.macd_signal), "#ef4444"),
        {
          type: "bar",
          label: "Histogram",
          data: rows.map((r) => r.macd_hist),
          backgroundColor: rows.map((r) =>
            (r.macd_hist ?? 0) >= 0 ? "rgba(34,197,94,0.45)" : "rgba(239,68,68,0.45)"
          ),
        },
      ],
    },
    options: {
      responsive: true,
      scales: { x: { ticks: { maxTicksLimit: 6 } } },
    },
  });

  const bbCtx = $("bbChart").getContext("2d");
  state.charts.bb = new Chart(bbCtx, {
    type: "line",
    data: {
      labels,
      datasets: [
        buildLineDataset("Upper", rows.map((r) => r.bb_upper), "#ef4444"),
        buildLineDataset("Middle", rows.map((r) => r.bb_middle), "#eab308"),
        buildLineDataset("Lower", rows.map((r) => r.bb_lower), "#22c55e"),
        buildLineDataset("Close", rows.map((r) => r.close), "#3b82f6"),
      ],
    },
    options: {
      responsive: true,
      scales: { x: { ticks: { maxTicksLimit: 8 } } },
    },
  });
}

function sentimentClass(label) {
  if (label === "positive" || label === "bullish" || label === "accumulation") return "positive";
  if (label === "negative" || label === "bearish" || label === "distribution") return "negative";
  return "neutral";
}

function renderTrendInsights(trend) {
  const overall = trend.overall || {};
  $("trendHero").innerHTML = `
    <div class="trend-card ${sentimentClass(overall.label)}">
      <div class="trend-label">${(overall.label || "neutral").toUpperCase()} TREND</div>
      <div class="trend-score">Score ${formatNumber(overall.score, 2)}</div>
      <p>${overall.suggested_action || ""}</p>
      <div class="trend-meta">${trend.market === "HK" ? "Hong Kong" : "US"} · ${trend.currency || ""} · ${trend.period}</div>
    </div>
  `;

  const drivers = overall.drivers || [];
  $("driverGrid").innerHTML = drivers
    .map(
      (driver) => `
      <div class="driver-card">
        <div class="label">${driver.factor}</div>
        <div class="value ${sentimentClass(driver.label)}">${(driver.label || "neutral").toUpperCase()}</div>
        <div class="sub">${formatNumber(driver.score, 2)}</div>
      </div>
    `
    )
    .join("");

  const notes = [
    ...(trend.technical?.notes || []),
    ...(trend.news?.notes || []),
    ...(trend.behavior?.notes || []),
  ];

  const newsItems = trend.recent_news || [];
  $("newsList").innerHTML = `
    <div class="behavior-grid">
      <div class="behavior-card">
        <div class="label">Volume vs 20-day avg</div>
        <div class="value">${trend.behavior?.volume_ratio ?? "—"}x</div>
      </div>
      <div class="behavior-card">
        <div class="label">5-day momentum</div>
        <div class="value">${formatPercent(trend.behavior?.momentum_5d)}</div>
      </div>
      <div class="behavior-card">
        <div class="label">Buy pressure</div>
        <div class="value">${formatNumber(trend.behavior?.buy_pressure, 2)}</div>
      </div>
      <div class="behavior-card">
        <div class="label">News sentiment</div>
        <div class="value ${sentimentClass(trend.news?.label)}">${(trend.news?.label || "neutral").toUpperCase()}</div>
      </div>
    </div>
    <ul class="notes-list">${notes.map((note) => `<li>${note}</li>`).join("")}</ul>
    ${newsItems
      .map(
        (item) => `
        <article class="news-item">
          <div class="news-head">
            <span class="news-sentiment ${sentimentClass(item.sentiment_label)}">${(item.sentiment_label || "neutral").toUpperCase()}</span>
            <span class="news-region">${item.region || "news"}</span>
          </div>
          <h4>${item.title}</h4>
          <p>${item.summary || ""}</p>
          <div class="news-meta">${item.source || ""}</div>
        </article>
      `
      )
      .join("")}
  `;
}

async function loadTrendInsights() {
  if (!state.symbol) return;
  const trend = await api(`/api/trend/${encodeURIComponent(state.symbol)}?period=${state.period === "1mo" ? "3mo" : state.period}`);
  state.trend = trend;
  renderTrendInsights(trend);
}

function renderFundamentals(data) {
  const fields = [
    ["Sector", data.sector],
    ["Industry", data.industry],
    ["Market Cap", formatLargeNumber(data.market_cap)],
    ["Enterprise Value", formatLargeNumber(data.enterprise_value)],
    ["P/E Ratio", formatNumber(data.pe_ratio, 2)],
    ["Forward P/E", formatNumber(data.forward_pe, 2)],
    ["PEG Ratio", formatNumber(data.peg_ratio, 2)],
    ["Price/Book", formatNumber(data.price_to_book, 2)],
    ["EPS", formatNumber(data.eps, 2)],
    ["Dividend Yield", data.dividend_yield != null ? formatPercent(data.dividend_yield * 100) : "—"],
    ["Beta", formatNumber(data.beta, 2)],
    ["52W High", formatNumber(data.fifty_two_week_high, 2)],
    ["52W Low", formatNumber(data.fifty_two_week_low, 2)],
    ["Avg Volume", formatLargeNumber(data.avg_volume)?.replace("$", "") || "—"],
  ];

  $("fundamentalsGrid").innerHTML = fields
    .map(
      ([label, value]) => `
      <div class="fund-card">
        <div class="label">${label}</div>
        <div class="value">${value || "—"}</div>
      </div>
    `
    )
    .join("");

  const description = data.description || "";
  $("descriptionCard").classList.toggle("hidden", !description);
  $("companyDescription").textContent = description;
}

async function renderCompare(defaultSymbols) {
  const input = defaultSymbols || $("compareInput").value.trim();
  if (!input) return;

  $("compareInput").value = input;
  const compare = await api(`/api/compare?symbols=${encodeURIComponent(input)}&period=${state.period}`);

  if (state.charts.compare) {
    state.charts.compare.destroy();
  }

  const colors = ["#3b82f6", "#22c55e", "#eab308", "#ef4444", "#a855f7"];
  const datasets = (compare.series || []).map((entry, index) =>
    buildLineDataset(entry.symbol, entry.points.map((p) => ({ x: p.date, y: p.value })), colors[index % colors.length])
  );

  const compareCtx = $("compareChart").getContext("2d");
  state.charts.compare = new Chart(compareCtx, {
    type: "line",
    data: { datasets },
    options: {
      responsive: true,
      parsing: false,
      plugins: { legend: { position: "bottom" } },
      scales: {
        x: { type: "time", time: { unit: "month" }, ticks: { maxTicksLimit: 8 } },
        y: { ticks: { callback: (v) => `${v}%` } },
      },
    },
  });
}

async function loadSymbol(symbol) {
  const normalized = symbol.trim().toUpperCase();
  if (!normalized) return;

  state.symbol = normalized;
  setLoading(true);

  try {
    const [quote, history, fundamentals, trend] = await Promise.all([
      api(`/api/quote/${encodeURIComponent(normalized)}`),
      api(`/api/history/${encodeURIComponent(normalized)}?period=${state.period}`),
      api(`/api/fundamentals/${encodeURIComponent(normalized)}`),
      api(`/api/trend/${encodeURIComponent(normalized)}?period=${state.period === "1mo" ? "3mo" : state.period}`),
    ]);

    state.quote = quote;
    state.history = history;
    state.fundamentals = fundamentals;
    state.trend = trend;

    renderHero(quote);
    renderMetrics(history);
    renderSignalBanner(history.signals || {});
    renderCharts(history);
    renderFundamentals(fundamentals);
    renderTrendInsights(trend);
    showPanels(true);
    activateTab("overview");
    closeSidebar();

    const compareDefaults = normalized.endsWith(".HK")
      ? [normalized, "0700.HK", "9988.HK"]
      : [normalized, "MSFT", "GOOGL"];
    $("compareInput").value = [...new Set(compareDefaults)].join(", ");
  } catch (error) {
    alert(error.message || "Failed to load stock data");
  } finally {
    setLoading(false);
  }
}

async function reloadHistory() {
  if (!state.symbol) return;
  setLoading(true);
  try {
    state.history = await api(`/api/history/${state.symbol}?period=${state.period}`);
    renderMetrics(state.history);
    renderSignalBanner(state.history.signals || {});
    renderCharts(state.history);
  } finally {
    setLoading(false);
  }
}

function activateTab(tabName) {
  document.querySelectorAll(".tab").forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.tab === tabName);
  });

  const panels = {
    overview: "overviewPanel",
    insights: "insightsPanel",
    technical: "technicalPanel",
    fundamentals: "fundamentalsPanel",
    compare: "comparePanel",
  };

  Object.entries(panels).forEach(([name, id]) => {
    $(id).classList.toggle("hidden", name !== tabName);
  });

  if (tabName === "compare" && state.symbol) {
    renderCompare($("compareInput").value).catch((error) => alert(error.message));
  }
  if (tabName === "insights" && state.symbol) {
    if (state.trend) {
      renderTrendInsights(state.trend);
    } else {
      loadTrendInsights().catch((error) => alert(error.message));
    }
  }
}

function setupSearch() {
  $("searchForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    const query = $("searchInput").value.trim();
    if (!query) return;

    if (/^[\d]{1,5}(\.HK)?$/i.test(query) || (/^[A-Za-z0-9.\-^]+$/i.test(query) && query.length <= 12)) {
      $("searchResults").classList.add("hidden");
      await loadSymbol(query);
      return;
    }

    const data = await api(`/api/search?q=${encodeURIComponent(query)}`);
    const container = $("searchResults");
    container.innerHTML = "";
    container.classList.toggle("hidden", !data.results.length);

    data.results.forEach((item) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.innerHTML = `
        ${item.symbol}
        <span class="meta">${item.name}${item.exchange ? ` · ${item.exchange}` : ""}</span>
      `;
      btn.addEventListener("click", () => {
        container.classList.add("hidden");
        $("searchInput").value = item.symbol;
        loadSymbol(item.symbol);
      });
      container.appendChild(btn);
    });
  });
}

function setupTabs() {
  document.querySelectorAll(".tab").forEach((tab) => {
    tab.addEventListener("click", () => activateTab(tab.dataset.tab));
  });
}

function setupPeriodTabs() {
  $("periodTabs").addEventListener("click", async (event) => {
    const button = event.target.closest("button[data-period]");
    if (!button) return;

    document.querySelectorAll("#periodTabs button").forEach((el) => el.classList.remove("active"));
    button.classList.add("active");
    state.period = button.dataset.period;
    await reloadHistory();
  });
}

function setupWatchlist() {
  $("addWatchlistBtn").addEventListener("click", () => {
    if (!state.symbol) return;
    const list = getWatchlist();
    if (!list.includes(state.symbol)) {
      list.unshift(state.symbol);
      saveWatchlist(list.slice(0, 20));
      renderWatchlist();
    }
  });

  $("clearWatchlist").addEventListener("click", () => {
    saveWatchlist([]);
    renderWatchlist();
  });
}

function setupCompare() {
  $("compareForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      await renderCompare();
    } catch (error) {
      alert(error.message || "Compare failed");
    }
  });
}

document.addEventListener("DOMContentLoaded", () => {
  renderWatchlist();
  renderPopularChips();
  setupSearch();
  setupTabs();
  setupPeriodTabs();
  setupWatchlist();
  setupCompare();

  $("menuToggle")?.addEventListener("click", () => {
    $("sidebar").classList.toggle("open");
  });
});
