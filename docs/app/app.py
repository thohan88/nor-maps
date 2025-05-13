from shiny import App, ui, reactive, render, req
from ipyleaflet import Map, GeoJSON, LayersControl, TileLayer, Popup
from shinywidgets import output_widget, render_widget
from faicons import icon_svg
from ipywidgets import HTML
import requests
import json
import numpy as np


def build_url(map_type, map_area, size):
    return f"https://raw.githubusercontent.com/thohan88/nor-maps/refs/heads/main/maps/current/{map_type}/{map_area}_{size}.geojson"


def build_github_url(map_type, map_area, size):
    return f"https://github.com/thohan88/nor-maps/blob/main/maps/current/{map_type}/{map_area}_{size}.geojson"


def get_polygon_center(coords):
    coords = np.array(coords[0])  # outer ring only
    lng, lat = coords[:, 0], coords[:, 1]
    return [lat.mean(), lng.mean()]


app_ui = ui.page_fillable(
    ui.head_content(ui.tags.title("Norwegian maps")),
    ui.head_content(
        ui.tags.style(
            ".bslib-page-fill {padding: 0 !important;}"
            ".jupyter-widgets {margin: 0 !important;}"
            ".map-inputs {z-index:1000 !important;}"
        )
    ),
    output_widget("map_output"),
    ui.panel_absolute(
        ui.card(
            ui.card_body(
                ui.input_select(
                    "map_type",
                    "Select type",
                    {"extended": "Extended", "landmask": "Landmask"},
                    selected="landmask",
                ),
                ui.input_select(
                    "map_area",
                    "Select areas",
                    {
                        "grunnkrets": "Grunnkrets",
                        "delomraade": "Delområde",
                        "bydel": "Bydel",
                        "kommune_bydel": "Kommune/Bydel",
                        "kommune": "Kommune",
                        "fylke": "Fylke",
                        "economic_region": "Økonomisk region",
                        "zip": "Zip Codes",
                    },
                    selected="grunnkrets",
                ),
                ui.input_radio_buttons(
                    "map_size",
                    "Choose size",
                    {"xs": "XS", "s": "S", "m": "M", "l": "L", "xl": "XL"},
                    inline=True,
                ),
                ui.layout_columns(
                    ui.output_ui("download_button"),
                    ui.output_ui("github_button"),
                    gap=3,
                ),
            ),
            gap=0,
        ),
        width="290px",
        top="10px",
        left="10px",
        draggable=False,
        class_="map-inputs small",
    ),
    ui.panel_absolute(
        ui.output_ui("feature"),
        width="290px",
        bottom="10px",
        left="10px",
        draggable=False,
        class_="map-inputs small",
    ),
    fillable_mobile=True,
)


def server(input, output, session):
    current_geojson_parsed_data = reactive.Value(None)
    current_geojson_raw_text = reactive.Value(None)
    current_geojson_feature = reactive.Value(None)

    m = Map(center=(65.5, 11.0), zoom=5, scroll_wheel_zoom=True)
    m.add(
        TileLayer(
            name="Basemap",
            tile_size=512,
            zoom_offset=-1,
            detect_retina=True,
            url="https://b.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png",
        )
    )

    _current_map_layer_object = None

    @output
    @render_widget
    def map_output():
        return m

    @reactive.effect
    @reactive.event(input.map_size, input.map_type, input.map_area)
    def _update_map_layer():
        nonlocal _current_map_layer_object
        req(input.map_type(), input.map_area(), input.map_size())

        url = build_url(input.map_type(), input.map_area(), input.map_size())
        layer_name = f"{input.map_area()} ({input.map_size()})"

        with ui.Progress(min=0, max=1) as p:
            p.set(message=f"Loading {layer_name}...")

            try:
                resp = requests.get(url, timeout=30)
                resp.raise_for_status()
                text = resp.text
                data = json.loads(text)
                layer = GeoJSON(data=data, name=layer_name)

                current_geojson_raw_text.set(text)
                current_geojson_parsed_data.set(data)

                if _current_map_layer_object:
                    m.remove_layer(_current_map_layer_object)

                def on_hover_handler(event, feature, **kwargs):
                    if not feature or "geometry" not in feature:
                        current_geojson_feature.set(None)
                        return

                    props = feature.get("properties", {})
                    table_rows = "".join(
                        f"""<tr class="small text-nowrap"><td class="text-muted pb-0 ps-0 pt-0">{k}</td><td class="p-0">{v}</td></tr>"""
                        for k, v in props.items()
                    )
                    content = f"""
                        <div>
                            <table class="table table-sm m-0">
                                {table_rows}
                            </table>
                        </div>
                    """
                    current_geojson_feature.set(content)

                layer.on_hover(on_hover_handler)

                m.add_layer(layer)
                _current_map_layer_object = layer

            except Exception as e:
                current_geojson_raw_text.set(None)
                current_geojson_parsed_data.set(None)
                ui.notification_show(str(e), type="error", duration=6)

    @render.download(
        filename=lambda: f"{input.map_type()}_{input.map_area()}_{input.map_size()}.geojson"
    )
    async def download_geojson():
        yield current_geojson_raw_text.get().encode("utf-8")

    @render.ui
    def feature():
        if current_geojson_feature() is None:
            return None
        return ui.card(
            ui.card_body(
                ui.HTML(current_geojson_feature()),
            )
        )

    @render.ui
    def download_button():
        return (
            ui.download_button(
                "download_geojson",
                "Download",
                icon=icon_svg("download"),
                class_="btn btn-sm btn-primary",
            ),
        )

    @render.ui
    def github_button():
        url = build_github_url(input.map_type(), input.map_area(), input.map_size())
        return ui.a(
            ui.span(icon_svg("github"), "Github"),
            href=url,
            class_="btn btn-sm btn-primary",
        )


app = App(app_ui, server)
