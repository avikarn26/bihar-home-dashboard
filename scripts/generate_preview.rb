#!/usr/bin/env ruby
jsx = File.read(File.join(__dir__, '..', 'home_construction_dashboard.jsx'))
jsx = jsx.sub(/import \{[^}]+\} from 'react';\n\n/, "const { useState, useEffect, useRef, useMemo } = React;\n\n")
jsx = jsx.sub(/export default function HomeConstructionDashboard/, 'function HomeConstructionDashboard')
jsx = jsx.sub('const [data, setData] = useState(null);', 'const [data, setData] = useState(INITIAL_DATA);')
jsx = jsx.sub(/useEffect\(\(\) => \{\s*\(async \(\) => \{[\s\S]*?\}\)\(\);\s*\}, \[\]\);/, '')
jsx += "\n\nconst root = ReactDOM.createRoot(document.getElementById('root'));\nroot.render(<HomeConstructionDashboard />);\n"

html = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Bihar Home Construction Dashboard</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #000; }
    #root { max-width: 390px; margin: 0 auto; }
  </style>
  <script crossorigin src="https://unpkg.com/react@18/umd/react.development.js"></script>
  <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
</head>
<body>
  <div id="root"></div>
  <script id="app-source" type="text/plain">
#{jsx}
  </script>
  <script>
    window.addEventListener('DOMContentLoaded', () => {
      try {
        const src = document.getElementById('app-source').textContent;
        const code = Babel.transform(src, { presets: ['react'] }).code;
        eval(code);
      } catch (e) {
        document.getElementById('root').innerHTML = '<pre style="color:#ff3b30;padding:20px">' + e.message + '</pre>';
      }
    });
  </script>
</body>
</html>
HTML

File.write(File.join(__dir__, '..', 'preview.html'), html)
puts "Generated preview.html (#{html.bytesize} bytes)"
