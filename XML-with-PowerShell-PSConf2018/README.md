# Werde zum XML Ninja mit PowerShell — PSConf.EU 2018

Companion script for the PSConf.EU 2018 session by Andreas Nick on working with XML in PowerShell. The file is a walkthrough — open it in ISE/VS Code and step through with **F8** (it intentionally throws on direct execution).

## What it covers

- Casting strings to `[xml]`, reading and writing element values
- A `Format-XML` helper for indented output
- Saving / loading XML via files
- Navigating arrays of elements, working with attributes (`SetAttribute` / `GetAttribute` / `RemoveAttribute`)
- **XPath** with `SelectSingleNode` / `SelectNodes` — predicates, `contains()`, `starts-with()`, `not(@attr)`
- Building XML from scratch with `System.Xml.XmlDocument`
- Namespaces and `XmlNamespaceManager`, `Select-Xml -Namespace`
- `Export-Clixml` / `Import-Clixml` / `ConvertTo-Xml`
- Practical example: editing a Windows `unattend.xml`

