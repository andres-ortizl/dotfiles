//! Deterministic, collision-aware port-offset allocation. Pure core logic; the CLI
//! supplies the real "is this port free" probe and the set of offsets already
//! reserved by other active specs.

use std::collections::BTreeMap;

use crate::config::PortSpec;

/// Pick the lowest offset (multiples of `step`, starting at `step` — offset 0 is the
/// user's own dev stack) such that it is not in `used_offsets` AND every
/// `base + offset` port satisfies `is_free`. Returns the offset and the resolved
/// service→port map. `None` if nothing fits up to `max`.
pub fn pick_offset(
    specs: &[PortSpec],
    used_offsets: &[u16],
    step: u16,
    max: u16,
    is_free: impl Fn(u16) -> bool,
) -> Option<(u16, BTreeMap<String, u16>)> {
    let mut offset = step;
    while offset <= max {
        let all_free = specs
            .iter()
            .all(|s| s.base.checked_add(offset).is_some_and(&is_free));
        if !used_offsets.contains(&offset) && all_free {
            let map = specs.iter().map(|s| (s.service.clone(), s.base + offset)).collect();
            return Some((offset, map));
        }
        offset += step;
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    fn spec(service: &str, base: u16) -> PortSpec {
        PortSpec { service: service.into(), base, env: format!("{}_PORT", service.to_uppercase()) }
    }

    #[test]
    fn picks_lowest_free_offset() {
        let specs = [spec("frontend", 5173), spec("backend", 8080)];
        let (offset, map) = pick_offset(&specs, &[], 10, 990, |_| true).unwrap();
        assert_eq!(offset, 10);
        assert_eq!(map["frontend"], 5183);
        assert_eq!(map["backend"], 8090);
    }

    #[test]
    fn skips_reserved_offset() {
        let specs = [spec("backend", 8080)];
        let (offset, _) = pick_offset(&specs, &[10, 20], 10, 990, |_| true).unwrap();
        assert_eq!(offset, 30);
    }

    #[test]
    fn skips_offset_when_a_port_is_busy() {
        let specs = [spec("frontend", 5173), spec("backend", 8080)];
        // 8090 (backend @ offset 10) is busy → offset 10 rejected, 20 taken.
        let (offset, map) = pick_offset(&specs, &[], 10, 990, |p| p != 8090).unwrap();
        assert_eq!(offset, 20);
        assert_eq!(map["backend"], 8100);
    }
}
