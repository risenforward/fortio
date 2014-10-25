if gon.local is "zh-CN"
  DATETIME_LABEL_FORMAT_FOR_TOOLTIP = 
    millisecond: ['%m月%e日, %H:%M:%S.%L', '%m月%e日, %H:%M:%S.%L', '-%H:%M:%S.%L']
    second:      ['%m月%e日, %H:%M:%S', '%m月%e日, %H:%M:%S', '-%H:%M:%S']
    minute:      ['%m月%e日, %H:%M', '%m月%e日, %H:%M', '-%H:%M']
    hour:        ['%m月%e日, %H:%M', '%m月%e日, %H:%M', '-%H:%M']
    day:         ['%Y年%m月%e日', '%Y年%m月%e日', '-%m月%e日']
    week:        ['%Y年%m月%e日', '%Y年%m月%e日', '-%m月%e日']
    month:       ['%Y年%m月', '%Y年%m月', '-%m']
    year: ['%Y', '%Y', '-%Y']

DATETIME_LABEL_FORMAT = 
  second: '%H:%M:%S'
  minute: '%H:%M'
  hour: '%H:%M'
  day: '%m-%d'
  week: '%m-%d'
  month: '%Y-%m'
  year: '%Y'

DATE_RANGE = 
  min1: 
    default_range: 1000 * 3600 * 2 # 2h
    dataGrouping_units: [['minute', [1]]]
  min5: 
    default_range: 1000 * 3600 * 10 # 10h
    dataGrouping_units: [['minute', [5]]]
  min15: 
    default_range: 1000 * 3600 * 24 * 1 # 1d
    dataGrouping_units: [['minute', [15]]]
  min30: 
    default_range: 1000 * 3600 * 24 * 2 # 2d
    dataGrouping_units: [['minute', [30]]]
  min60: 
    default_range: 1000 * 3600 * 24 * 5 # 5d
    dataGrouping_units: [['hour', [1]]]
  min120: 
    default_range: 1000 * 3600 * 24 * 10 # 10d
    dataGrouping_units: [['hour', [2]]]
  min360: 
    default_range: 1000 * 3600 * 24 * 30 * 1 # 1m 
    dataGrouping_units: [['hour', [6]]]
  min1440: 
    default_range: 1000 * 3600 * 24 * 30 * 3 # 3m
    dataGrouping_units: [['day', [1]]]
  min4320: 
    default_range: 1000 * 3600 * 24 * 30 * 9 # 9m
    dataGrouping_units: [['day', [3]]]
  min10080: 
    default_range: 1000 * 3600 * 24 * 30 * 12 # 12m
    dataGrouping_units: [['day', [7]]]

RANGE_DEFAULT = 
  fill: 'none',
  stroke: 'none',
  'stroke-width': 0,
  r: 8,
  style:
    color: '#333',
  states:
    hover:
      fill: '#000',
      style:
        color: '#ccc'
    select:
      fill: '#000',
      style:
        color: '#eee'

@CandlestickUI = flight.component ->
  @refresh = (event, data) ->
    @$node.highcharts()?.destroy()
    @initHighStock(data)
    @initTooltip()

  @initTooltip = ->
    chart = @$node.highcharts()
    tooltips = []
    for i in [0..3]
      if chart.series[i].points.length > 0
        tooltips.push chart.series[i].points[chart.series[i].points.length - 1]
    chart.tooltip.refresh tooltips

  @initHighStock = (data) ->
    range = DATE_RANGE["min#{data['minutes']}"]['default_range']
    unit = $("[data-unit=#{data['minutes']}]").text()
    title = "#{gon.market.base_unit.toUpperCase()}/#{gon.market.quote_unit.toUpperCase()} - #{unit}"

    dataGrouping =
      units: DATE_RANGE["min#{data['minutes']}"]['dataGrouping_units']

    if DATETIME_LABEL_FORMAT_FOR_TOOLTIP
        dataGrouping['dateTimeLabelFormats'] = DATETIME_LABEL_FORMAT_FOR_TOOLTIP

    @$node.highcharts "StockChart",

      title:
        text: title
        align: 'right'
        style:
          color: 'rgba(119, 119, 119, 0.6)'
          fontSize: 24

      chart:
        marginTop: 100
        marginLeft: 15
        backgroundColor: 'rgba(0,0,0, 0.0)'

      credits:
        enabled: false

      tooltip:
        crosshairs: [{
            width: 0.5,
            dashStyle: 'solid',
            color: '#777'
        }, false],
        valueDecimals: gon.market.bid.fixed
        borderWidth: 0
        backgroundColor: 'rgba(0,0,0,0)'
        borderRadius: 2
        shadow: false
        useHTML: true
        shared: true
        headerFormat: "<div class='chart-ticker'><span class='tooltip-title'>{point.key}</span><br />"
        footerFormat: '</div>'
        positioner: -> {x: 10, y: 8}

      plotOptions:
        candlestick:
          followPointer: true
          color: '#990f0f'
          upColor: '#000000'
          lineColor: '#cc1414'
          upLineColor: '#49c043'
          dataGrouping: dataGrouping
          tooltip:
            pointFormat:
              """
              <div class='tooltip-ticker'><span class=t-title>#{gon.i18n.chart.open}</span><span class=t-value>{point.open}</span></div>
              <div class='tooltip-ticker'><span class=t-title>#{gon.i18n.chart.close}</span><span class=t-value>{point.close}</span></div>
              <div class='tooltip-ticker'><span class=t-title>#{gon.i18n.chart.high}</span><span class=t-value>{point.high}</span></div>
              <div class='tooltip-ticker'><span class=t-title>#{gon.i18n.chart.low}</span><span class=t-value>{point.low}</span></div>
              """
        column:
          turboThreshold: 5000
          dataGrouping: dataGrouping
          tooltip:
            pointFormat:
              """
              <div class='tooltip-ticker'><span class=t-title>#{gon.i18n.chart.volume}</span><span class=t-value>{point.y}</span></div><br/>
              """
        spline:
          lineWidth: 1
          dataGrouping: dataGrouping
          tooltip:
            pointFormat:
              """
              <div class='tooltip-ma'><span class='t-title'>{series.name}</span><span class='t-value'>{point.y}</span></div>
              """

      scrollbar:
        buttonArrowColor: '#333'
        barBackgroundColor: '#202020'
        buttonBackgroundColor: '#202020'
        trackBackgroundColor: '#202020'
        barBorderColor: '#2a2a2a'
        buttonBorderColor: '#2a2a2a'
        trackBorderColor: '#2a2a2a'

      rangeSelector: 
        enabled: false

      xAxis:
        type: 'datetime',
        dateTimeLabelFormats: DATETIME_LABEL_FORMAT
        lineColor: '#333'
        tickColor: '#333'
        tickWidth: 2
        range: range

      navigator:
        maskFill: 'rgba(32, 32, 32, 0.6)'
        outlineColor: '#333'
        outlineWidth: 1
        xAxis:
          dateTimeLabelFormats: DATETIME_LABEL_FORMAT

      yAxis: [
        {
          labels:
            enabled: true
          gridLineColor: '#222'
          gridLineDashStyle: 'ShortDot'
          top: "0%"
          height: "80%"
        }
        {
          labels:
            enabled: false
          top: "80%"
          gridLineColor: '#000'
          height: "20%"
        }
      ]

      legend:
        enabled: true
        align: 'left'
        verticalAlign: 'top'
        layout: 'vertical'
        y: 100
        itemStyle: 
          color: '#777'
        itemHoverStyle:
          color: '#eee'
        itemHiddenStyle:
          color: '#333'

      series: [
        {
          name: gon.i18n.chart.candlestick
          type: "candlestick"
          data: data['candlestick']
          showInLegend: false
        }
        {
          name: gon.i18n.chart.volume
          yAxis: 1
          type: "column"
          data: data['volume']
          color: '#777'
          showInLegend: false
        }
        {
          name: 'MA5'
          type: 'spline'
          data: data['ma5']
          color: '#7c9aaa'
        }
        {
          name: 'MA10'
          type: 'spline'
          data: data['ma10']
          color: '#be8f53'
        }
        {
          name: 'MA15'
          type: 'spline'
          data: data['ma15']
          visible: false
        }
        {
          name: 'MA30'
          type: 'spline'
          data: data['ma30']
          visible: false
        }
      ]

  @after 'initialize', ->
    @on document, 'market::candlestick::response', @refresh
