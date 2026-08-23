use ratatui::{
    Frame,
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, ListState, Paragraph, Tabs},
};

use crate::{
    app::{AppState, ConnectionStatus, InputMode, Tab},
    spotify::{MediaItem, MediaKind},
};

const BASE: Color = Color::Rgb(30, 30, 46);
const MANTLE: Color = Color::Rgb(24, 24, 37);
const PANEL: Color = Color::Rgb(49, 50, 68);
const SURFACE_1: Color = Color::Rgb(69, 71, 90);
const TEXT: Color = Color::Rgb(205, 214, 244);
const MUTED: Color = Color::Rgb(166, 173, 200);
const MAUVE: Color = Color::Rgb(203, 166, 247);
const BLUE: Color = Color::Rgb(137, 180, 250);
const GREEN: Color = Color::Rgb(166, 227, 161);
const YELLOW: Color = Color::Rgb(249, 226, 175);
const RED: Color = Color::Rgb(243, 139, 168);

pub fn render(frame: &mut Frame, app: &AppState, now_ms: u64) {
    frame.render_widget(
        Block::default().style(Style::default().fg(TEXT).bg(BASE)),
        frame.area(),
    );
    let areas = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(16),
            Constraint::Length(3),
        ])
        .split(frame.area());

    let content = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Min(50), Constraint::Length(30)])
        .split(areas[1]);

    render_navigation(frame, app, areas[0]);
    match app.active_tab {
        Tab::NowPlaying => render_now_playing(frame, app, now_ms, content[0]),
        Tab::Queue => render_queue(frame, app, content[0]),
        Tab::Search => render_search(frame, app, content[0]),
        Tab::Library => render_library(frame, app, content[0]),
        Tab::Playlists => render_playlists(frame, app, content[0]),
    }
    render_legend(frame, content[1]);
    render_footer(frame, app, areas[2]);
}

fn render_navigation(frame: &mut Frame, app: &AppState, area: Rect) {
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Length(18), Constraint::Min(40)])
        .split(area);
    frame.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled("  ● ", Style::default().fg(GREEN)),
            Span::styled("SOLOIST", Style::default().add_modifier(Modifier::BOLD)),
        ]))
        .style(Style::default().fg(TEXT).bg(MANTLE))
        .block(
            Block::default()
                .borders(Borders::BOTTOM)
                .border_style(Style::default().fg(SURFACE_1)),
        ),
        columns[0],
    );
    let tabs = Tabs::new(["Now Playing", "Queue", "Search", "Library", "Playlists"])
        .select(app.active_tab.index())
        .style(Style::default().fg(MUTED).bg(MANTLE))
        .highlight_style(
            Style::default()
                .fg(MAUVE)
                .add_modifier(Modifier::BOLD | Modifier::UNDERLINED),
        )
        .divider("  ")
        .block(
            Block::default()
                .borders(Borders::BOTTOM)
                .border_style(Style::default().fg(SURFACE_1)),
        );
    frame.render_widget(tabs, columns[1]);
}

fn render_legend(frame: &mut Frame, area: Rect) {
    let section = Style::default().fg(BLUE).add_modifier(Modifier::BOLD);
    let lines = vec![
        Line::from(Span::styled(" PLAYBACK", section)),
        legend_line("Space", "Play / Pause"),
        legend_line("n / p", "Next / Previous"),
        legend_line("← / →", "Seek 10 seconds"),
        legend_line("+ / -", "Volume"),
        legend_line("s / r", "Shuffle / Repeat"),
        Line::from(""),
        Line::from(Span::styled(" BROWSE", section)),
        legend_line("j / k", "Move selection"),
        legend_line("Enter", "Play selected"),
        legend_line("1-5", "Change view"),
        legend_line("/", "Search"),
        legend_line("Esc", "Leave search"),
        legend_line("g", "Refresh"),
        Line::from(""),
        Line::from(Span::styled(" LIBRARY", section)),
        legend_line("a", "Add to queue"),
        legend_line("l / d", "Save / Remove"),
        legend_line("[ / ]", "Media type"),
        Line::from(""),
        Line::from(Span::styled(" APP", section)),
        legend_line("q", "Quit"),
    ];
    frame.render_widget(
        Paragraph::new(lines)
            .style(Style::default().fg(TEXT).bg(MANTLE))
            .block(
                Block::default()
                    .title(" CONTROLS ")
                    .title_style(Style::default().fg(MAUVE).add_modifier(Modifier::BOLD))
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(SURFACE_1)),
            ),
        area,
    );
}

fn legend_line(keys: &'static str, action: &'static str) -> Line<'static> {
    Line::from(vec![
        Span::styled(format!(" {keys:<7}"), Style::default().fg(MAUVE)),
        Span::styled(action, Style::default().fg(MUTED)),
    ])
}

fn render_now_playing(frame: &mut Frame, app: &AppState, now_ms: u64, area: Rect) {
    let outer = Block::default().style(Style::default().fg(TEXT).bg(BASE));
    frame.render_widget(outer, area);
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(34), Constraint::Percentage(66)])
        .margin(2)
        .split(area);

    let artwork = Paragraph::new(vec![
        Line::from(""),
        Line::from(Span::styled(
            "♫",
            Style::default().fg(MAUVE).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(Span::styled("SPOTIFY", Style::default().fg(MUTED))),
    ])
    .alignment(Alignment::Center)
    .style(Style::default().fg(TEXT).bg(MANTLE))
    .block(
        Block::default()
            .title(" COVER ")
            .borders(Borders::ALL)
            .border_style(Style::default().fg(SURFACE_1)),
    );
    frame.render_widget(artwork, columns[0]);

    let details = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Min(5),
            Constraint::Length(3),
            Constraint::Length(2),
        ])
        .margin(1)
        .split(columns[1]);
    let (title, creators, duration) = app.playback.item.as_ref().map_or_else(
        || {
            (
                "Nothing playing".to_owned(),
                "Start playback from Spotify".to_owned(),
                0,
            )
        },
        |item| {
            (
                item.name().to_owned(),
                item.creators().join(", "),
                item.duration_ms().unwrap_or_default(),
            )
        },
    );
    frame.render_widget(
        Paragraph::new(vec![
            Line::from(Span::styled(
                title,
                Style::default().add_modifier(Modifier::BOLD),
            )),
            Line::from(Span::styled(creators, Style::default().fg(MUTED))),
        ])
        .block(Block::default().title(" NOW PLAYING ")),
        details[0],
    );

    let position = app.playback.position_at(now_ms);
    let ratio = if duration == 0 {
        0.0
    } else {
        position as f64 / duration as f64
    };
    frame.render_widget(
        Gauge::default()
            .block(Block::default().borders(Borders::TOP))
            .gauge_style(Style::default().fg(GREEN).bg(PANEL))
            .ratio(ratio.clamp(0.0, 1.0))
            .label(format!(
                "{} / {}",
                format_time(position),
                format_time(duration)
            )),
        details[1],
    );
    frame.render_widget(
        Paragraph::new(format!(
            "{}    shuffle {}    repeat {:?}    volume {}%",
            playback_icon(app),
            if app.playback.options.shuffle {
                "on"
            } else {
                "off"
            },
            app.playback.repeat_mode(),
            app.playback.volume,
        ))
        .style(Style::default().fg(MUTED)),
        details[2],
    );
}

fn render_queue(frame: &mut Frame, app: &AppState, area: Rect) {
    let items = app
        .queue
        .iter()
        .enumerate()
        .map(|(index, entry)| {
            let creators = entry.item.creators().join(", ");
            ListItem::new(Line::from(vec![
                Span::styled(format!("{:02}  ", index + 1), Style::default().fg(MUTED)),
                Span::styled(
                    entry.item.name().to_owned(),
                    Style::default().add_modifier(Modifier::BOLD),
                ),
                Span::styled(format!("  {creators}"), Style::default().fg(MUTED)),
            ]))
        })
        .collect::<Vec<_>>();
    render_list(
        frame,
        items,
        app.selection(),
        area,
        " PLAY QUEUE ",
        "The Soloist queue is empty",
    );
}

fn render_search(frame: &mut Frame, app: &AppState, area: Rect) {
    let areas = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(5)])
        .margin(1)
        .split(area);
    let cursor = if app.input_mode == InputMode::Search {
        "█"
    } else {
        ""
    };
    frame.render_widget(
        Paragraph::new(format!("Search: {}{cursor}", app.search_query))
            .style(
                Style::default()
                    .fg(if app.input_mode == InputMode::Search {
                        MAUVE
                    } else {
                        TEXT
                    })
                    .bg(MANTLE),
            )
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(SURFACE_1)),
            ),
        areas[0],
    );
    render_media_list(
        frame,
        &app.search_results,
        app.selection(),
        areas[1],
        if app.spotify_loading {
            " RESULTS · LOADING "
        } else {
            " RESULTS "
        },
        "Press / to search Spotify",
    );
}

fn render_library(frame: &mut Frame, app: &AppState, area: Rect) {
    let title = format!(
        " YOUR LIBRARY · {} · [ / ] CHANGE TYPE ",
        kind_label(app.library_kind)
    );
    render_media_list(
        frame,
        &app.library_items,
        app.selection(),
        area.inner(ratatui::layout::Margin {
            horizontal: 1,
            vertical: 1,
        }),
        &title,
        if app.spotify_loading {
            "Loading library…"
        } else {
            "No saved items"
        },
    );
}

fn render_playlists(frame: &mut Frame, app: &AppState, area: Rect) {
    render_media_list(
        frame,
        &app.playlists,
        app.selection(),
        area.inner(ratatui::layout::Margin {
            horizontal: 1,
            vertical: 1,
        }),
        " YOUR PLAYLISTS ",
        if app.spotify_loading {
            "Loading playlists…"
        } else {
            "No playlists"
        },
    );
}

fn render_media_list(
    frame: &mut Frame,
    media: &[MediaItem],
    selected: usize,
    area: Rect,
    title: &str,
    empty: &str,
) {
    let items = media
        .iter()
        .map(|item| {
            ListItem::new(Line::from(vec![
                Span::styled(
                    format!("{}  ", kind_icon(item.kind)),
                    Style::default().fg(GREEN),
                ),
                Span::styled(
                    item.name.clone(),
                    Style::default().add_modifier(Modifier::BOLD),
                ),
                Span::styled(format!("  {}", item.subtitle), Style::default().fg(MUTED)),
            ]))
        })
        .collect::<Vec<_>>();
    render_list(frame, items, selected, area, title, empty);
}

fn render_list(
    frame: &mut Frame,
    items: Vec<ListItem<'static>>,
    selected: usize,
    area: Rect,
    title: &str,
    empty: &str,
) {
    if items.is_empty() {
        frame.render_widget(
            Paragraph::new(empty)
                .alignment(Alignment::Center)
                .style(Style::default().fg(MUTED))
                .block(Block::default().title(title).borders(Borders::ALL)),
            area,
        );
        return;
    }
    let list = List::new(items)
        .block(
            Block::default()
                .title(title)
                .borders(Borders::ALL)
                .border_style(Style::default().fg(SURFACE_1)),
        )
        .highlight_symbol("▶ ")
        .highlight_style(
            Style::default()
                .fg(BASE)
                .bg(MAUVE)
                .add_modifier(Modifier::BOLD),
        );
    let mut state = ListState::default();
    state.select(Some(selected));
    frame.render_stateful_widget(list, area, &mut state);
}

const fn kind_icon(kind: MediaKind) -> &'static str {
    match kind {
        MediaKind::Track => "♪",
        MediaKind::Album => "▣",
        MediaKind::Artist => "●",
        MediaKind::Playlist => "≡",
        MediaKind::Show => "◉",
        MediaKind::Episode => "▶",
        MediaKind::Audiobook => "▤",
    }
}

const fn kind_label(kind: MediaKind) -> &'static str {
    match kind {
        MediaKind::Track => "TRACKS",
        MediaKind::Album => "ALBUMS",
        MediaKind::Artist => "ARTISTS",
        MediaKind::Playlist => "PLAYLISTS",
        MediaKind::Show => "SHOWS",
        MediaKind::Episode => "EPISODES",
        MediaKind::Audiobook => "AUDIOBOOKS",
    }
}

fn render_footer(frame: &mut Frame, app: &AppState, area: Rect) {
    let connection = match app.soloist_connection {
        ConnectionStatus::Connected => Span::styled("● connected", Style::default().fg(GREEN)),
        ConnectionStatus::Connecting => Span::styled("◌ connecting", Style::default().fg(YELLOW)),
        ConnectionStatus::Disconnected => Span::styled("● offline", Style::default().fg(RED)),
    };
    let default_status = if app.spotify_authenticated {
        "q quit   1-5 tabs   / search"
    } else {
        "Soloist-only mode   configure Spotify Web API for Search and Library"
    };
    let status = app.status_message.as_deref().unwrap_or(default_status);
    frame.render_widget(
        Paragraph::new(Line::from(vec![
            connection,
            Span::raw("   "),
            Span::raw(status),
        ]))
        .style(Style::default().fg(MUTED).bg(MANTLE))
        .block(
            Block::default()
                .borders(Borders::TOP)
                .border_style(Style::default().fg(SURFACE_1)),
        ),
        area,
    );
}

fn playback_icon(app: &AppState) -> &'static str {
    use crate::soloist::PlaybackStatus;
    match app.playback.status {
        PlaybackStatus::Playing => "▶ playing",
        PlaybackStatus::Paused => "Ⅱ paused",
        PlaybackStatus::Buffering => "◌ buffering",
        PlaybackStatus::Idle => "■ idle",
    }
}

fn format_time(milliseconds: u64) -> String {
    let seconds = milliseconds / 1000;
    format!("{}:{:02}", seconds / 60, seconds % 60)
}
