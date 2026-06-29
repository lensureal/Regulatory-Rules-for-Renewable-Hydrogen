# Results

This folder is populated when you run a scenario script (e.g. `include("00_default.jl")`).
The generated CSV / Tableau files are intentionally **not** committed to the repository —
they are reproduced by running the model.

Each run writes the following files, suffixed with the scenario name
(`_00_default`, `_01_additionality`, `_02_temporal_correlation`, `_03_geographic_correlation`):

| File | Contents |
| --- | --- |
| `EnergyBalance_<scenario>.csv` | Hourly production, use, demand, storage, trade and unmet demand per region and carrier. |
| `Capacity_<scenario>.csv` | New and accumulated installed capacity per technology, region and year. |
| `StorageLevel_<scenario>.csv` | Hourly storage level per storage, region and carrier. |
| `Emissions_<scenario>.csv` | Annual emissions per technology and region. |
| `DetailedTrade_<scenario>.csv` | Inter-regional imports and exports. |
| `ObjectiveValue_<scenario>.csv` | Total discounted system cost (objective value). |
