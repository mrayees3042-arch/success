import React, { useState } from 'react';
import { SafeAreaView, StyleSheet } from 'react-native';
import LifePlan2027 from './LifePlan2027';
import IncomeScreen from './IncomeScreen';

export default function App() {
  const [activeTab, setActiveTab] = useState('today');

  return (
    <SafeAreaView style={styles.safeArea}>
      {activeTab === 'today' ? (
        <LifePlan2027 onTabChange={setActiveTab} />
      ) : (
        <IncomeScreen onTabChange={setActiveTab} />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
  },
});
