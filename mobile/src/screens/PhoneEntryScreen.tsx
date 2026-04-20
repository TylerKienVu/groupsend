import { View, Text, StyleSheet } from 'react-native';

export default function PhoneEntryScreen() {
  return (
    <View style={styles.container}>
      <Text>Phone Entry</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
