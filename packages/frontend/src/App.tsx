import React from 'react';
import logo from './logo.svg';
import './App.css';
import { useFindTopicQuery, useFindTopicsQuery } from './generated/graphql';


function App() {
  const { data, error, loading } = useFindTopicQuery();
  const { data: list } = useFindTopicsQuery();
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Edit <code>src/App.tsx</code> and save to reload. learn react
        </p>
        <ul>
          topic.title = { data?.topic?.title }
        </ul>
        {
          list?.topics?.map(item => (
            <li key={item?.id}>{item?.title}</li>
          ))
        }

        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </header>
    </div>
  );
}

export default App;
