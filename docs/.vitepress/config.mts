import { defineConfig } from 'vitepress'

const gh = 'https://github.com/lb091188/moonbit-libyue'

// 落地页语言自动选择:首次访问根路径时,浏览器语言为中文则跳转 /zh/,
// 其余语言留在默认英文;用户手动切换过语言(localStorage 有记录)后不再跳转。
const langDetect = `(function () {
  try {
    if (localStorage.getItem('docs-lang')) return
    if (location.pathname !== '/' && location.pathname !== '/index.html') return
    var langs = navigator.languages && navigator.languages.length
      ? navigator.languages
      : [navigator.language || '']
    for (var i = 0; i < langs.length; i++) {
      if (String(langs[i]).toLowerCase().indexOf('zh') === 0) {
        localStorage.setItem('docs-lang', 'zh')
        location.replace('zh/')
        return
      }
    }
  } catch (e) {}
})()`

// Minimal TextMate grammar so ```moonbit blocks get keyword/string/number
// highlighting instead of falling back to plain text.
const moonbitGrammar = {
  name: 'moonbit',
  scopeName: 'source.moonbit',
  patterns: [{ include: '#expression' }],
  repository: {
    expression: {
      patterns: [
        { include: '#comments' },
        { include: '#strings' },
        { include: '#numbers' },
        { include: '#keywords' },
      ],
    },
    comments: {
      patterns: [
        { name: 'comment.line.double-slash.moonbit', match: '//.*$' },
      ],
    },
    strings: {
      patterns: [
        { name: 'string.quoted.double.moonbit', begin: '"', end: '"' },
      ],
    },
    numbers: {
      patterns: [
        { name: 'constant.numeric.moonbit', match: '\\b\\d[\\d_]*(?:\\.[\\d_]+)?\\b' },
      ],
    },
    keywords: {
      patterns: [
        {
          name: 'keyword.control.moonbit',
          match: '\\b(?:fn|let|mut|const|type|struct|enum|trait|impl|pub|priv|if|else|match|while|for|loop|return|break|continue|true|false|raise|try|catch|test|using|as|extern|derive|guard|Self)\\b',
        },
      ],
    },
  },
}

export default defineConfig({
  title: 'moonbit-libyue',
  description: 'libyue 的 MoonBit 封装:统一跨平台桌面 GUI API',
  cleanUrls: true,
  lastUpdated: true,
  head: [
    ['script', {}, langDetect],
  ],
  markdown: {
    languages: [moonbitGrammar],
  },
  themeConfig: {
    search: { provider: 'local' },
  },
  locales: {
    root: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'Tutorial', link: '/tutorial' },
          { text: 'Packages', link: '/README' },
          { text: 'GitHub', link: gh },
        ],
        sidebar: [
          {
            text: 'Guide',
            items: [
              { text: 'Five-minute tutorial', link: '/tutorial' },
              { text: 'About libyue', link: '/aboutlibyue' },
            ],
          },
          {
            text: 'Building UI',
            items: [
              { text: 'Declarative UI', link: '/declarative' },
              { text: 'Layout style keys', link: '/layout' },
              { text: 'Themed components', link: '/components-ui' },
              { text: 'Native widgets (internal)', link: '/components' },
            ],
          },
          {
            text: 'Reference',
            items: [
              { text: 'Doc index', link: '/README' },
              { text: 'Platform adaptation', link: '/adaptation' },
              { text: 'Linux tray', link: '/tray' },
              { text: 'Autostart', link: '/autostart' },
              { text: 'Native-layer relink', link: '/relink' },
            ],
          },
        ],
        docFooter: { prev: 'Previous', next: 'Next' },
        outline: { label: 'On this page' },
      },
    },
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      link: '/zh/',
      themeConfig: {
        nav: [
          { text: '教程', link: '/zh/tutorial' },
          { text: '包结构', link: '/zh/README' },
          { text: 'GitHub', link: gh },
        ],
        sidebar: [
          {
            text: '指南',
            items: [
              { text: '五分钟上手教程', link: '/zh/tutorial' },
              { text: '关于 libyue', link: '/zh/aboutlibyue' },
            ],
          },
          {
            text: '界面开发',
            items: [
              { text: '声明式 UI', link: '/zh/declarative' },
              { text: '布局样式键', link: '/zh/layout' },
              { text: '主题组件库', link: '/zh/components-ui' },
              { text: '原生控件(内部)', link: '/zh/components' },
            ],
          },
          {
            text: '系统能力',
            items: [
              { text: '系统能力总览', link: '/zh/system-capabilities' },
              { text: '系统集成计划', link: '/zh/plan-system-integration' },
              { text: '开机自启动', link: '/zh/autostart' },
              { text: 'Linux 托盘', link: '/zh/tray' },
            ],
          },
          {
            text: '工程参考',
            items: [
              { text: '文档索引', link: '/zh/README' },
              { text: '平台适配经验', link: '/zh/adaptation' },
              { text: '异步共存调研', link: '/zh/async-research' },
              { text: '原生层重链', link: '/zh/relink' },
            ],
          },
        ],
        docFooter: { prev: '上一页', next: '下一页' },
        outline: { label: '页面目录' },
      },
    },
  },
})
