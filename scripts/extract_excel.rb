#!/usr/bin/env ruby
require 'rexml/document'
require 'json'

NS = { 'xmlns' => 'http://schemas.openxmlformats.org/spreadsheetml/2006/main' }

def load_shared_strings(path)
  doc = REXML::Document.new(File.read(path))
  strings = []
  REXML::XPath.each(doc, '//xmlns:si', NS) do |si|
    parts = []
    REXML::XPath.each(si, './/xmlns:t', NS) { |t| parts << (t.text || '') }
    strings << parts.join
  end
  strings
end

def col_to_num(col)
  col.bytes.reduce(0) { |n, c| n * 26 + (c - 64) }
end

def parse_cell_value(c, shared)
  v_el = REXML::XPath.first(c, 'xmlns:v', NS)
  return nil unless v_el
  raw = v_el.text
  return nil if raw.nil?

  if c.attributes['t'] == 's'
    shared[raw.to_i]
  elsif c.attributes['t'] == 'inlineStr'
    t = REXML::XPath.first(c, './/xmlns:t', NS)
    t ? t.text : ''
  elsif raw.include?('.')
    raw.to_f
  else
    raw.to_i
  end
end

def parse_sheet(path, shared)
  doc = REXML::Document.new(File.read(path))
  rows = {}
  REXML::XPath.each(doc, '//xmlns:row', NS) do |row|
    rnum = row.attributes['r'].to_i
    rows[rnum] ||= {}
    REXML::XPath.each(row, 'xmlns:c', NS) do |c|
      ref = c.attributes['r']
      col = ref.gsub(/\d+/, '')
      rows[rnum][col_to_num(col)] = parse_cell_value(c, shared)
    end
  end
  rows
end

def excel_serial_to_date(serial)
  require 'date'
  base = Date.new(1899, 12, 30)
  d = base + serial.to_i
  months = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
  format('%02d-%s', d.day, months[d.month - 1])
end

def fmt_date(d)
  return d if d.is_a?(String) && d.match?(/^\d{2}-[A-Za-z]{3}$/)
  if d.is_a?(String) && d.match?(%r{^\d{2}-\d{2}-\d{4}$})
    dd, mm, _yyyy = d.split('-')
    months = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
    return "#{dd}-#{months[mm.to_i - 1]}"
  end
  if d.is_a?(Numeric) || (d.is_a?(String) && d.match?(/^\d+(\.\d+)?$/))
    return excel_serial_to_date(d.to_f)
  end
  d.to_s
end

def money_badge(amount)
  if amount >= 100_000
    "₹#{(amount / 100_000.0).round(2)}L"
  elsif amount >= 1000
    "₹#{(amount / 1000.0).round(1)}K"
  else
    "₹#{amount.round}"
  end
end

def payer_name(pb)
  %w[Self-GPay Self-Bank\ Transfer].include?(pb) ? 'Avinash' : pb
end

def bar_color(category)
  case category
  when 'Building Materials' then '#ff6b35'
  when 'Steel/Iron' then '#888'
  when /Cement/ then '#007aff'
  when /Dr Fixit|Chemical/ then '#30b0c7'
  else '#636366'
  end
end

def cat_color(category)
  {
    'Building Materials' => '#ff6b35',
    'Steel/Iron' => '#888',
    'Professional Fees' => '#007aff',
    'Land Development' => '#ff9500',
    'Labour' => '#af52de'
  }[category] || '#636366'
end

def cat_icon(category)
  {
    'Building Materials' => '🧱',
    'Steel/Iron' => '🔩',
    'Professional Fees' => '👷',
    'Land Development' => '🚜',
    'Labour' => '👥',
    'Transport' => '🚛',
    'Food/Provisions' => '🍚',
    'Miscellaneous' => '📦'
  }[category] || '📦'
end

xlsx_path = ARGV[0] || '/Users/avinashkarn/Downloads/Project_Home_01062026 (2).xlsx'
extract_dir = '/tmp/xlsx_extract'
`unzip -o -q "#{xlsx_path}" -d "#{extract_dir}"`

base = "#{extract_dir}/xl"
shared = load_shared_strings("#{base}/sharedStrings.xml")
txn_rows = parse_sheet("#{base}/worksheets/sheet4.xml", shared)
pay_rows = parse_sheet("#{base}/worksheets/sheet6.xml", shared)

txns = []
(5..(txn_rows.keys.max || 5)).each do |r|
  row = txn_rows[r]
  next unless row && row[1]
  sr = row[1].to_s.strip
  next if sr.empty? || sr.upcase == 'TOTALS' || sr !~ /\A\d+\z/
  net = row[15].to_f
  next if net <= 0 && row[7].to_s.strip.empty?
  txns << {
    sr: row[1], date: row[2], month: row[3], phase: row[4], category: row[5],
    subcategory: row[6], item: row[7], vendor: row[8], qty: row[9], unit: row[10],
    rate: row[11], gross: row[12], disc_pct: row[13], disc_amt: row[14], net: row[15],
    paid_by: row[16], payment_mode: row[17]
  }
end

payments = []
(5..(pay_rows.keys.max || 5)).each do |r|
  row = pay_rows[r]
  next unless row && row[2]
  next if row[7].to_f <= 0
  payments << {
    date: row[2], paid_by: row[3], paid_to: row[4], category: row[5],
    desc: row[6], amount: row[7], mode: row[8], notes: row[13]
  }
end

total_paid = payments.sum { |p| p[:amount].to_f }
total_billed = txns.sum { |t| t[:net].to_f }

payer_map = Hash.new { |h, k| h[k] = { amount: 0, count: 0, payments: [] } }
payments.each do |p|
  key = payer_name(p[:paid_by])
  payer_map[key][:amount] += p[:amount].to_f
  payer_map[key][:count] += 1
  payer_map[key][:payments] << {
    date: fmt_date(p[:date]),
    to: p[:paid_to],
    desc: p[:desc],
    amt: p[:amount].to_f,
    mode: p[:mode]
  }
end

mukesh_txns = txns.select { |t| t[:vendor].to_s.include?('Mukesh') }
mukesh_billed = mukesh_txns.sum { |t| t[:net].to_f }
mukesh_paid = payments.select { |p| p[:paid_to].to_s.include?('Mukesh') }.sum { |p| p[:amount].to_f }

brick_txns = txns.select { |t| t[:vendor].to_s.include?('Brick') }
brick_billed = brick_txns.sum { |t| t[:net].to_f }
brick_paid = payments.select { |p| p[:paid_to].to_s.include?('Brick') }.sum { |p| p[:amount].to_f }
brick_received = brick_txns.sum { |t| t[:qty].to_f }
brick_rate = brick_txns.first ? brick_txns.first[:rate].to_f : 8.5
brick_total_est = 43_000

mitti_txns = mukesh_txns.select { |t| t[:subcategory].to_s.include?('Mitti') || t[:item].to_s.downcase.include?('mitti') || t[:item].to_s.downcase.include?('trailer') }
batch1 = mitti_txns.find { |t| t[:item].to_s.include?('19') }
batch2 = mitti_txns.find { |t| t[:item].to_s.include?('22') }

vendor_groups = txns.group_by { |t| t[:vendor] }
vendor_paid = Hash.new(0.0)
payments.each { |p| vendor_paid[p[:paid_to]] += p[:amount].to_f if p[:paid_to] }

action_vendors = []
settled_vendors = []
vendor_groups.each do |name, items|
  next unless name
  billed = items.sum { |t| t[:net].to_f }
  paid = vendor_paid[name].to_f
  due = billed - paid
  next if name.include?('Brick') || name.include?('Mukesh')

  entry = {
    name: name,
    cat: items.map { |t| t[:category] }.uniq.join(', '),
    amt: billed,
    paid: paid,
    items: items.map do |t|
      {
        date: fmt_date(t[:date]),
        item: t[:item],
        qty: t[:qty],
        unit: t[:unit],
        rate: t[:rate],
        total: t[:net].to_f
      }
    end
  }
  if due > 1
    action_vendors << {
      name: name,
      cat: entry[:cat],
      paid: paid,
      badge: "₹#{due >= 1000 ? (due / 1000.0).round(1).to_s + 'K' : due.round} DUE",
      badgeType: 'y'
    }
  else
    settled_vendors << entry
  end
end
settled_vendors.sort_by! { |v| -v[:amt] }

if mukesh_billed - mukesh_paid > 1
  action_vendors.unshift({
    name: 'Mukesh Yadav',
    cat: 'JCB + Mitti filling',
    paid: mukesh_paid,
    badge: "#{money_badge(mukesh_billed - mukesh_paid)} DUE",
    badgeType: 'y'
  })
end

mat_groups = txns.group_by { |t| t[:subcategory] }
materials = mat_groups.map do |sub, items|
  amt = items.sum { |t| t[:net].to_f }
  qty = items.sum { |t| t[:qty].to_f }
  unit = items.first[:unit]
  rate = items.first[:rate]
  category = items.first[:category]
  {
    name: sub,
    amt: amt,
    barColor: bar_color(category.to_s + ' ' + sub.to_s),
    detail: "#{qty} #{unit} @ ₹#{rate}",
    purchases: items.map do |t|
      {
        date: fmt_date(t[:date]),
        qty: t[:qty],
        unit: t[:unit],
        rate: t[:rate],
        total: t[:net].to_f,
        vendor: t[:vendor]
      }
    end
  }
end.sort_by { |m| -m[:amt] }

cat_groups = txns.group_by { |t| t[:category] }
categories = cat_groups.map do |cat, items|
  amt = items.sum { |t| t[:net].to_f }
  pct = total_billed > 0 ? (amt / total_billed * 100).round(1) : 0
  sub_groups = items.group_by { |t| t[:subcategory] }
  sub_items = sub_groups.map do |sub, sub_txns|
    sub_amt = sub_txns.sum { |t| t[:net].to_f }
  {
      name: sub,
      amt: sub_amt,
      detail: sub_txns.map { |t| t[:item] }.first
    }
  end.sort_by { |s| -s[:amt] }
  {
    name: cat,
    icon: cat_icon(cat),
    amt: amt,
    pct: pct,
    color: cat_color(cat),
    sub: sub_items.map { |s| s[:name] }.join(', '),
    items: sub_items
  }
end.sort_by { |c| -c[:amt] }

latest_date = txns.map { |t| t[:date] }.compact.last
updated = if latest_date.is_a?(String) && latest_date.match?(%r{^\d{2}-\d{2}-\d{4}$})
  dd, mm, yyyy = latest_date.split('-')
  months = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
  "#{dd} #{months[mm.to_i - 1]} #{yyyy}"
else
  '01 Jun 2026'
end

payer_colors = { 'Avinash' => '#007aff', 'Papa' => '#ff9500', 'Chota Bhai' => '#34c759' }
payers = %w[Avinash Papa Chota\ Bhai].map do |name|
  data = payer_map[name]
  {
    name: name,
    color: payer_colors[name],
    amount: data[:amount],
    count: data[:count],
    payments: data[:payments].sort_by { |p| p[:date].to_s }.reverse
  }
end

brick_pct = brick_total_est > 0 ? (brick_received / brick_total_est * 100).round(1) : 0

initial_data = {
  updated: updated,
  phase: 'Plinth',
  phasesDone: ['Land Development', 'Foundation'],
  estBudget: 2_500_000,
  kpis: {
    totalPaid: total_paid,
    materialBilled: total_billed,
    vendorAdvance: brick_paid - brick_billed,
    pending: mukesh_billed - mukesh_paid,
    txns: txns.length,
    payments: payments.length,
    vendors: vendor_groups.keys.compact.length
  },
  alerts: [
    {
      type: 'orange',
      title: "#{money_badge(mukesh_billed - mukesh_paid)} Due — Mukesh Yadav",
      desc: "JCB + Mitti: billed ₹#{mukesh_billed.round}, paid ₹#{mukesh_paid.round}. Balance pending."
    },
    {
      type: 'blue',
      title: "Brick Co. — #{brick_pct}% Delivered",
      desc: "#{brick_received.to_i} bricks received of ~#{brick_total_est}. Advance remaining ₹#{(brick_paid - brick_billed).round}."
    }
  ],
  payers: payers,
  vendors: {
    action: action_vendors,
    brick: {
      advance: brick_paid,
      received: brick_received,
      total: brick_total_est,
      rate: brick_rate,
      lastDelivery: brick_txns.last ? brick_txns.last[:item] : '',
      pct: brick_pct
    },
    mitti: {
      totalTrailers: mitti_txns.sum { |t| t[:qty].to_f },
      batch1: batch1 ? batch1[:qty].to_f : 0,
      batch2: batch2 ? batch2[:qty].to_f : 0,
      rate: batch1 ? batch1[:rate].to_f : 600,
      totalCost: mitti_txns.sum { |t| t[:net].to_f },
      paid: mukesh_paid,
      vendor: 'Mukesh Yadav'
    },
    settled: settled_vendors
  },
  materials: materials,
  categories: categories,
  notes: ''
}

summary = {
  total_paid: total_paid,
  total_billed: total_billed,
  payers: payers.map { |p| { name: p[:name], amount: p[:amount], count: p[:count] } },
  mukesh: { billed: mukesh_billed, paid: mukesh_paid, due: mukesh_billed - mukesh_paid },
  brick: { billed: brick_billed, paid: brick_paid, advance_remaining: brick_paid - brick_billed }
}

out_dir = File.dirname(__FILE__) + '/..'
File.write("#{out_dir}/data/initial_data.json", JSON.pretty_generate(initial_data))
File.write("#{out_dir}/data/summary.json", JSON.pretty_generate(summary))
puts JSON.pretty_generate(summary)
